--[[
  NampowerDB
  Crash-persistent SavedVariables replacement using nampower's file API.

  Usage:
    NampowerDB_Register("MyAddon_SaveData", "myaddon.lua", {
      periodic = true,       -- enable periodic writing (default: true)
      interval = 30,         -- seconds between writes (default: 30, minimum: 10)
      events   = {           -- additional events that trigger a write (optional)
        "AUCTION_HOUSE_CLOSED",
      },
    })

  PLAYER_LOGOUT is always registered regardless of options.
  An event-triggered write resets the periodic timer.
  On load, the newer of SavedVariables and the file wins (compared via last_saved).
  On failure to load a file, an error is raised loudly. Remove the file manually to fall back.
]]

local NAMPOWER_DB_MIN_INTERVAL = 10
local NAMPOWER_DB_VERSION = 1

-- Registry of all registered variables
-- Each entry: { globalName, filename, options, elapsed }
local NampowerDB_Registry = {}

-- Whether nampower file API is available
local NampowerDB_Available = false

-- The single OnUpdate frame shared across all registrations
local NampowerDB_Frame = nil

-- ---------------------------------------------------------------------------
-- Availability check
-- ---------------------------------------------------------------------------

local function NampowerDB_CheckAvailable()
  local ok, major, minor, patch = pcall(GetNampowerVersion)
  if ok and major then
    if major > 3 or (major == 3 and minor > 2) or (major == 3 and minor == 2 and patch >= 0) then
      NampowerDB_Available = true
    else
      NampowerDB_Available = false
    end
  else
    NampowerDB_Available = false
  end
  return NampowerDB_Available
end

-- ---------------------------------------------------------------------------
-- Serializer
-- Outputs a Lua expression representing a value.
-- Supports strings, numbers, booleans, nil, and nested tables.
-- ---------------------------------------------------------------------------

-- Pre-computed indent strings to avoid string.rep allocations during serialization
local NampowerDB_Indent = {}
for i = 0, 20 do
  NampowerDB_Indent[i] = string.rep("  ", i)
end

-- Lookup table for boolean serialization to avoid any tostring ambiguity
local NampowerDB_BoolStr = {}
NampowerDB_BoolStr[true] = "true"
NampowerDB_BoolStr[false] = "false"

local function NampowerDB_SerializeValue(value, indent, buf)
  local t = type(value)

  if t == "nil" then
    table.insert(buf, "nil")
  elseif t == "boolean" then
    table.insert(buf, NampowerDB_BoolStr[value])
  elseif t == "number" then
    table.insert(buf, tostring(value) .. "")
  elseif t == "string" then
    local escaped = string.gsub(value, "\\", "\\\\")
    escaped = string.gsub(escaped, '"', '\\"')
    escaped = string.gsub(escaped, "\n", "\\n")
    escaped = string.gsub(escaped, "\r", "\\r")
    escaped = string.gsub(escaped, "%z", "\\0")
    table.insert(buf, '"')
    table.insert(buf, escaped)
    table.insert(buf, '"')
  elseif t == "table" then
    local pad = NampowerDB_Indent[indent + 1] or string.rep("  ", indent + 1)
    local padEnd = NampowerDB_Indent[indent] or string.rep("  ", indent)

    -- Check if empty first
    local empty = true
    for k, v in pairs(value) do
      empty = false
      break
    end

    if empty then
      table.insert(buf, "{}")
      return
    end

    table.insert(buf, "{\n")
    for k, v in pairs(value) do
      table.insert(buf, pad)
      if type(k) == "string" and string.find(k, "^[%a_][%w_]*$") then
        table.insert(buf, k)
      elseif type(k) == "number" then
        table.insert(buf, "[")
        table.insert(buf, tostring(k) .. "")
        table.insert(buf, "]")
      else
        table.insert(buf, "[")
        NampowerDB_SerializeValue(k, 0, buf)
        table.insert(buf, "]")
      end
      table.insert(buf, " = ")
      NampowerDB_SerializeValue(v, indent + 1, buf)
      table.insert(buf, ",\n")
    end
    table.insert(buf, padEnd)
    table.insert(buf, "}")
  else
    error("NampowerDB: cannot serialize value of type '" .. t .. "'")
  end
end

local function NampowerDB_Serialize(value)
  local buf = {}
  NampowerDB_SerializeValue(value, 0, buf)
  return table.concat(buf)
end

-- ---------------------------------------------------------------------------
-- Write a registered entry to disk
-- Updates last_saved on the table before writing.
-- ---------------------------------------------------------------------------

local function NampowerDB_Write(entry)
  if not NampowerDB_Available then
    return
  end

  local tbl = getglobal(entry.globalName)
  if tbl == nil then
    ACC_Print("|cFFFF0000NampowerDB: cannot write '" .. entry.globalName .. "', global is nil|r")
    return
  end

  local ok, result, contents, filename

  if entry.multi_file then
    -- Multi-file mode: write only the current key's subtable to its own file.
    -- Each per-character file calls NampowerDB_MultiLoad so reads merge rather
    -- than replace the global.
    local key = entry.multi_file.write_key_fn()
    if key == nil or tbl[key] == nil then
      return
    end

    local ts = time()
    tbl[key]._ts = ts

    local subset = { last_saved = ts }
    subset[key] = tbl[key]

    ok, result = pcall(NampowerDB_Serialize, subset)
    if not ok then
      error("NampowerDB: serialization failed for '" .. entry.globalName .. "': " .. tostring(result))
    end

    filename = string.format(entry.filename, key)
    contents = "NampowerDB_MultiLoad(" .. '"' .. entry.globalName .. '", ' .. result .. ")\n"
  else
    -- Original single-file mode.
    tbl.last_saved = time()

    ok, result = pcall(NampowerDB_Serialize, tbl)
    if not ok then
      error("NampowerDB: serialization failed for '" .. entry.globalName .. "': " .. tostring(result))
    end

    filename = entry.filename
    contents = "NampowerDB_Load(" .. '"' .. entry.globalName .. '", ' .. result .. ")\n"
  end

  WriteCustomFile(filename, contents, "w")

  -- Collect the garbage created by serialization immediately so it doesn't
  -- accumulate into a large collection that could cause a noticeable hitch
  collectgarbage()
end

-- ---------------------------------------------------------------------------
-- NampowerDB_Load
-- Called by the executed file. Compares last_saved and overwrites the global
-- if the file is newer. If the global has no last_saved, the file wins.
-- ---------------------------------------------------------------------------

function NampowerDB_Load(globalName, fileData)
  if type(fileData) ~= "table" then
    error("NampowerDB: file data for '" .. globalName .. "' is not a table")
  end

  local current = getglobal(globalName)

  -- If the global doesn't exist yet or has no last_saved, file wins
  if current == nil or current.last_saved == nil then
    setglobal(globalName, fileData)
    return
  end

  -- If the file has no last_saved, it predates this system — global wins,
  -- but we schedule an immediate write by setting file's last_saved to 0
  if fileData.last_saved == nil then
    fileData.last_saved = 0
  end

  if fileData.last_saved >= current.last_saved then
    setglobal(globalName, fileData)
  end
  -- If current is newer, do nothing — the periodic writer will update the file
end

-- ---------------------------------------------------------------------------
-- NampowerDB_MultiLoad
-- Called by per-key files written in multi_file mode.
-- Merges each key from fileData into the global using per-entry _ts comparison
-- so two concurrent sessions never clobber each other's data.
-- ---------------------------------------------------------------------------

function NampowerDB_MultiLoad(globalName, fileData)
  if type(fileData) ~= "table" then
    error("NampowerDB: file data for '" .. globalName .. "' is not a table")
  end

  local current = getglobal(globalName)
  if current == nil then
    setglobal(globalName, fileData)
    return
  end

  for key, charData in pairs(fileData) do
    if key ~= "last_saved" and type(charData) == "table" then
      local currentChar = current[key]
      if currentChar == nil or (charData._ts or 0) > (currentChar._ts or 0) then
        current[key] = charData
      end
    end
  end

  -- Keep the global last_saved at the highest value seen across all files
  if fileData.last_saved then
    if current.last_saved == nil or fileData.last_saved > current.last_saved then
      current.last_saved = fileData.last_saved
    end
  end
end

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------

local function NampowerDB_OnEvent(event)
  if not NampowerDB_Available then
    return
  end

  for i = 1, table.getn(NampowerDB_Registry) do
    local entry = NampowerDB_Registry[i]
    for j = 1, table.getn(entry.events) do
      if entry.events[j] == event then
        NampowerDB_Write(entry)
        -- Reset the periodic timer so we don't double-write shortly after
        entry.elapsed = 0
        break
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- NampowerDB_Register
-- ---------------------------------------------------------------------------

function NampowerDB_Register(globalName, filename, options)
  if not NampowerDB_CheckAvailable() then
    -- Nampower not present — silently do nothing, SavedVariables will work normally
    return
  end

  options = options or {}

  local periodic = true
  if options.periodic == false then
    periodic = false
  end

  local interval = options.interval or 30
  if interval < NAMPOWER_DB_MIN_INTERVAL then
    interval = NAMPOWER_DB_MIN_INTERVAL
  end

  -- Build event list, always including PLAYER_LOGOUT
  local events = {}
  local hasLogout = false
  if options.events then
    for i = 1, table.getn(options.events) do
      table.insert(events, options.events[i])
      if options.events[i] == "PLAYER_LOGOUT" then
        hasLogout = true
      end
    end
  end
  if not hasLogout then
    table.insert(events, "PLAYER_LOGOUT")
  end

  local entry = {
    globalName = globalName,
    filename = filename,
    periodic = periodic,
    interval = interval,
    events = events,
    elapsed = 0,
    multi_file = options.multi_file or nil,
  }

  table.insert(NampowerDB_Registry, entry)

  -- Register events on the shared frame
  for i = 1, table.getn(events) do
    NampowerDB_Frame:RegisterEvent(events[i])
  end

  if entry.multi_file then
    -- Multi-file mode: load this session's per-key file, then load all other
    -- known per-key files and merge them into the global.
    local writeKey = entry.multi_file.write_key_fn()
    local primaryFile = string.format(filename, writeKey)

    if CustomFileExists(primaryFile) then
      local ok, err = pcall(ExecuteCustomLuaFile, primaryFile)
      if not ok then
        error(
          "NampowerDB: failed to load file '"
            .. primaryFile
            .. "' for '"
            .. globalName
            .. "'.\n"
            .. "Error: "
            .. tostring(err)
            .. "\n"
            .. "Remove the file manually if you wish to fall back to SavedVariables."
        )
      end
    else
      -- No file yet for this key — write current SavedVariables data immediately
      local tbl = getglobal(globalName)
      if tbl ~= nil then
        NampowerDB_Write(entry)
      end
    end

    -- Load all other per-key files and merge their data
    if entry.multi_file.read_keys_fn then
      local tbl = getglobal(globalName)
      if tbl ~= nil then
        local keys = entry.multi_file.read_keys_fn(tbl)
        for i = 1, table.getn(keys) do
          local key = keys[i]
          if key ~= writeKey then
            local otherFile = string.format(filename, key)
            if CustomFileExists(otherFile) then
              local ok, err = pcall(ExecuteCustomLuaFile, otherFile)
              if not ok then
                ACC_Print(
                  "|cFFFF0000NampowerDB: failed to load '"
                    .. otherFile
                    .. "': "
                    .. tostring(err)
                    .. "|r"
                )
              end
            end
          end
        end
      end
    end
  else
    -- Original single-file mode
    if CustomFileExists(filename) then
      local ok, err = pcall(ExecuteCustomLuaFile, filename)
      if not ok then
        error(
          "NampowerDB: failed to load file '"
            .. filename
            .. "' for '"
            .. globalName
            .. "'.\n"
            .. "Error: "
            .. tostring(err)
            .. "\n"
            .. "Remove the file manually if you wish to fall back to SavedVariables."
        )
      end
    else
      -- No file yet — if SavedVariables data exists, write it to file immediately
      local tbl = getglobal(globalName)
      if tbl ~= nil then
        NampowerDB_Write(entry)
      end
    end
  end
end

-- ---------------------------------------------------------------------------
-- Frame setup — runs at file load time
-- ---------------------------------------------------------------------------

local NampowerDB_Throttle = 0
local NampowerDB_THROTTLE_INTERVAL = 1 -- only check once per second

local function NampowerDB_CreateFrame()
  NampowerDB_Frame = CreateFrame("Frame", "NampowerDBFrame", UIParent)

  NampowerDB_Frame:SetScript("OnEvent", function()
    NampowerDB_OnEvent(event)
  end)

  NampowerDB_Frame:SetScript("OnUpdate", function()
    if not NampowerDB_Available then
      return
    end

    NampowerDB_Throttle = NampowerDB_Throttle + arg1
    if NampowerDB_Throttle < NampowerDB_THROTTLE_INTERVAL then
      return
    end
    NampowerDB_Throttle = 0

    for i = 1, table.getn(NampowerDB_Registry) do
      local entry = NampowerDB_Registry[i]
      if entry.periodic then
        entry.elapsed = entry.elapsed + NampowerDB_THROTTLE_INTERVAL
        if entry.elapsed >= entry.interval then
          entry.elapsed = 0
          NampowerDB_Write(entry)
        end
      end
    end
  end)
end

NampowerDB_CreateFrame()
