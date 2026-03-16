Accountant_Version = "3.0"
Accountant_Data = nil
Accountant_SaveData = nil
Accountant_Disabled = false
Accountant_Mode = ""
Accountant_CurrentMoney = 0
Accountant_LastMoney = 0
Accountant_Verbose = nil
Accountant_GotName = false
Accountant_CurrentTab = 1
Accountant_LogModes = { "Session", "Day", "Week", "Total" }
Accountant_Player = ""
local Accountant_RepairAllItems_old
local Accountant_CursorHasItem_old

function Accountant_RegisterEvents(frame)
  frame:RegisterEvent("MERCHANT_SHOW")
  frame:RegisterEvent("MERCHANT_CLOSED")

  frame:RegisterEvent("QUEST_COMPLETE")
  frame:RegisterEvent("QUEST_FINISHED")

  frame:RegisterEvent("LOOT_OPENED")
  frame:RegisterEvent("LOOT_CLOSED")

  frame:RegisterEvent("TAXIMAP_OPENED")
  frame:RegisterEvent("TAXIMAP_CLOSED")

  frame:RegisterEvent("TRADE_SHOW")
  frame:RegisterEvent("TRADE_CLOSE")

  frame:RegisterEvent("MAIL_SHOW")
  frame:RegisterEvent("MAIL_CLOSED")

  frame:RegisterEvent("TRAINER_SHOW")
  frame:RegisterEvent("TRAINER_CLOSED")

  frame:RegisterEvent("AUCTION_HOUSE_SHOW")
  frame:RegisterEvent("AUCTION_HOUSE_CLOSED")

  frame:RegisterEvent("CHAT_MSG_MONEY")

  frame:RegisterEvent("PLAYER_MONEY")

  frame:RegisterEvent("UNIT_NAME_UPDATE")
  frame:RegisterEvent("PLAYER_ENTERING_WORLD")
end

function Accountant_SetLabels()
  if Accountant_CurrentTab == 5 then
    AccountantFrameSource:SetText(ACCLOC_CHAR)
    AccountantFrameIn:SetText(ACCLOC_MONEY)
    AccountantFrameOut:SetText(ACCLOC_UPDATED)
    AccountantFrameTotalIn:SetText(ACCLOC_SUM .. ":")
    AccountantFrameTotalOut:SetText("")
    AccountantFrameTotalFlow:SetText("")
    AccountantFrameTotalInValue:SetText("")
    AccountantFrameTotalOutValue:SetText("")
    AccountantFrameTotalFlowValue:SetText("")
    for i = 1, 15, 1 do
      getglobal("AccountantFrameRow" .. i .. "Title"):SetText("")
      getglobal("AccountantFrameRow" .. i .. "In"):SetText("")
      getglobal("AccountantFrameRow" .. i .. "Out"):SetText("")
    end
    AccountantFrameResetButton:Hide()
    return
  end
  AccountantFrameResetButton:Show()

  AccountantFrameSource:SetText(ACCLOC_SOURCE)
  AccountantFrameIn:SetText(ACCLOC_IN)
  AccountantFrameOut:SetText(ACCLOC_OUT)
  AccountantFrameTotalIn:SetText(ACCLOC_TOT_IN .. ":")
  AccountantFrameTotalOut:SetText(ACCLOC_TOT_OUT .. ":")
  AccountantFrameTotalFlow:SetText(ACCLOC_NET .. ":")

  -- Row Labels (auto generate)
  local inPos = 1
  for key, value in pairs(Accountant_Data) do
    Accountant_Data[key].InPos = inPos
    getglobal("AccountantFrameRow" .. inPos .. "Title"):SetText(Accountant_Data[key].Title)
    inPos = inPos + 1
  end

  -- Set the header
  local header = getglobal("AccountantFrameTitleText")
  if header then
    header:SetText(ACCLOC_TITLE .. " " .. Accountant_Version)
  end
end

function Accountant_OnLoad()
  Accountant_Player = UnitName("player")

  -- Setup
  Accountant_LoadData()
  Accountant_SetLabels()

  -- Current Cash
  Accountant_CurrentMoney = GetMoney()
  Accountant_LastMoney = Accountant_CurrentMoney

  -- Slash Commands
  SlashCmdList["ACCOUNTANT"] = Accountant_Slash
  SLASH_ACCOUNTANT1 = "/accountant"
  SLASH_ACCOUNTANT2 = "/acc"

  -- Add myAddOns support
  if myAddOnsList then
    myAddOnsList.Accountant = {
      name = "Accountant",
      description = "Tracks your incomings / outgoings",
      version = Accountant_Version,
      frame = "AccountantFrame",
      optionsframe = "AccountantFrame",
    }
  end

  -- Confirm box
  StaticPopupDialogs["ACCOUNTANT_RESET"] = {
    text = TEXT("meh"),
    button1 = TEXT(OKAY),
    button2 = TEXT(CANCEL),
    OnAccept = function()
      Accountant_ResetConfirmed()
    end,
    showAlert = 1,
    timeout = 0,
    exclusive = 1,
    whileDead = 1,
    interruptCinematic = 1,
  }

  -- Hooks
  Accountant_RepairAllItems_old = RepairAllItems
  RepairAllItems = Accountant_RepairAllItems
  Accountant_CursorHasItem_old = CursorHasItem
  CursorHasItem = Accountant_CursorHasItem

  -- Tabs
  AccountantFrameTab1:SetText(ACCLOC_SESS)
  PanelTemplates_TabResize(10, AccountantFrameTab1)
  AccountantFrameTab2:SetText(ACCLOC_DAY)
  PanelTemplates_TabResize(10, AccountantFrameTab2)
  AccountantFrameTab3:SetText(ACCLOC_WEEK)
  PanelTemplates_TabResize(10, AccountantFrameTab3)
  AccountantFrameTab4:SetText(ACCLOC_TOTAL)
  PanelTemplates_TabResize(10, AccountantFrameTab4)
  AccountantFrameTab5:SetText(ACCLOC_CHARS)
  PanelTemplates_TabResize(10, AccountantFrameTab5)
  PanelTemplates_SetNumTabs(AccountantFrame, 5)
  PanelTemplates_SetTab(AccountantFrame, AccountantFrameTab1)
  PanelTemplates_UpdateTabs(AccountantFrame)

  Accountant_CheckDate()

  -- Register with NampowerDB for crash-persistent storage if nampower is available
  NampowerDB_Register("Accountant_SaveData", "accountant.lua", {
    periodic = true,
    interval = 30,
    events = { "PLAYER_LOGOUT" },
  })

  ACC_Print(ACCLOC_TITLE .. " " .. Accountant_Version .. " " .. ACCLOC_LOADED)
end

function Accountant_LoadData()
  Accountant_Data = {}
  Accountant_Data["LOOT"] = { Title = ACCLOC_LOOT }
  Accountant_Data["MERCH"] = { Title = ACCLOC_MERCH }
  Accountant_Data["QUEST"] = { Title = ACCLOC_QUEST }
  Accountant_Data["TRADE"] = { Title = ACCLOC_TRADE }
  Accountant_Data["MAIL"] = { Title = ACCLOC_MAIL }
  Accountant_Data["AH"] = { Title = ACCLOC_AUC }
  Accountant_Data["TRAIN"] = { Title = ACCLOC_TRAIN }
  Accountant_Data["TAXI"] = { Title = ACCLOC_TAXI }
  Accountant_Data["REPAIRS"] = { Title = ACCLOC_REPAIR }
  Accountant_Data["OTHER"] = { Title = ACCLOC_OTHER }

  for key, value in pairs(Accountant_Data) do
    for modekey, mode in pairs(Accountant_LogModes) do
      Accountant_Data[key][mode] = { In = 0, Out = 0 }
    end
  end

  if Accountant_SaveData == nil then
    Accountant_SaveData = {}
  end
  if Accountant_SaveData[Accountant_Player] == nil then
    local cdate = date()
    cdate = string.sub(cdate, 0, 8)
    Accountant_SaveData[Accountant_Player] = {
      options = {
        showbutton = true,
        buttonpos = 0,
        version = Accountant_Version,
        date = cdate,
        weekdate = "",
        weekstart = 3,
        totalcash = 0,
      },
      data = {},
    }
    ACC_Print(ACCLOC_NEWPROFILE .. " " .. Accountant_Player)
  else
    ACC_Print(ACCLOC_LOADPROFILE .. " " .. Accountant_Player)
  end

  if Accountant_SaveData[Accountant_Player]["options"] == nil then
    local cdate = date()
    cdate = string.sub(cdate, 0, 8)
    Accountant_SaveData[Accountant_Player]["options"] = {
      showbutton = true,
      buttonpos = 0,
      version = Accountant_Version,
      date = cdate,
      weekdate = "",
      weekstart = 3,
      totalcash = 0,
    }
  end

  if Accountant_SaveData[Accountant_Player]["data"] == nil then
    Accountant_SaveData[Accountant_Player]["data"] = {}
  end

  local order = 1
  for key, value in pairs(Accountant_Data) do
    if Accountant_SaveData[Accountant_Player]["data"][key] == nil then
      Accountant_SaveData[Accountant_Player]["data"][key] = {}
    end
    for modekey, mode in pairs(Accountant_LogModes) do
      if Accountant_SaveData[Accountant_Player]["data"][key][mode] == nil then
        Accountant_SaveData[Accountant_Player]["data"][key][mode] = { In = 0, Out = 0 }
      end
      Accountant_Data[key][mode].In = Accountant_SaveData[Accountant_Player]["data"][key][mode].In
      Accountant_Data[key][mode].Out = Accountant_SaveData[Accountant_Player]["data"][key][mode].Out
    end
    Accountant_Data[key]["Session"].In = 0
    Accountant_Data[key]["Session"].Out = 0

    -- Old version data conversion (pre-2.3)
    if Accountant_SaveData[Accountant_Player]["data"][key].TotalIn ~= nil then
      Accountant_SaveData[Accountant_Player]["data"][key]["Total"].In =
        Accountant_SaveData[Accountant_Player]["data"][key].TotalIn
      Accountant_Data[key]["Total"].In = Accountant_SaveData[Accountant_Player]["data"][key].TotalIn
      Accountant_SaveData[Accountant_Player]["data"][key].TotalIn = nil
    end
    if Accountant_SaveData[Accountant_Player]["data"][key].TotalOut ~= nil then
      Accountant_SaveData[Accountant_Player]["data"][key]["Total"].Out =
        Accountant_SaveData[Accountant_Player]["data"][key].TotalOut
      Accountant_Data[key]["Total"].Out = Accountant_SaveData[Accountant_Player]["data"][key].TotalOut
      Accountant_SaveData[Accountant_Player]["data"][key].TotalOut = nil
    end
    if Accountant_SaveData[key] ~= nil then
      Accountant_SaveData[key] = nil
    end
    -- End old version conversion

    Accountant_Data[key].order = order
    order = order + 1
  end

  Accountant_SaveData[Accountant_Player]["options"].version = Accountant_Version
  Accountant_SaveData[Accountant_Player]["options"].totalcash = GetMoney()

  if Accountant_SaveData[Accountant_Player]["options"]["weekstart"] == nil then
    Accountant_SaveData[Accountant_Player]["options"]["weekstart"] = 3
  end
  if Accountant_SaveData[Accountant_Player]["options"]["dateweek"] == nil then
    Accountant_SaveData[Accountant_Player]["options"]["dateweek"] = Accountant_WeekStart()
  end
  if Accountant_SaveData[Accountant_Player]["options"]["date"] == nil then
    local cdate = date()
    cdate = string.sub(cdate, 0, 8)
    Accountant_SaveData[Accountant_Player]["options"]["date"] = cdate
  end
end

function Accountant_Slash(msg)
  if msg == nil or msg == "" then
    msg = "log"
  end
  local args = { n = 0 }
  local function helper(word)
    table.insert(args, word)
  end
  string.gsub(msg, "[_%w]+", helper)
  if args[1] == "log" then
    ShowUIPanel(AccountantFrame)
  elseif args[1] == "verbose" then
    if Accountant_Verbose == nil then
      Accountant_Verbose = 1
      ACC_Print(ACCLOC_VERBOSE_ON)
    else
      Accountant_Verbose = nil
      ACC_Print(ACCLOC_VERBOSE_OFF)
    end
  elseif args[1] == "week" then
    ACC_Print(Accountant_WeekStart())
  else
    Accountant_ShowUsage()
  end
end

function Accountant_OnEvent(event)
  local oldmode = Accountant_Mode
  if (event == "UNIT_NAME_UPDATE" and arg1 == "player") or (event == "PLAYER_ENTERING_WORLD") then
    if Accountant_GotName then
      return
    end
    local playerName = UnitName("player")
    if playerName ~= UNKNOWNBEING and playerName ~= UNKNOWNOBJECT and playerName ~= nil then
      Accountant_GotName = true
      Accountant_OnLoad()
      AccountantOptions_OnLoad()
      AccountantButton_Init()
      AccountantButton_UpdatePosition()
    end
    return
  end
  if event == "MERCHANT_SHOW" then
    Accountant_Mode = "MERCH"
  elseif event == "MERCHANT_CLOSED" then
    Accountant_Mode = ""
  elseif event == "TAXIMAP_OPENED" then
    Accountant_Mode = "TAXI"
  elseif event == "TAXIMAP_CLOSED" then
    -- Mode intentionally not cleared: taximap closes before the money transaction fires
  elseif event == "LOOT_OPENED" then
    Accountant_Mode = "LOOT"
  elseif event == "LOOT_CLOSED" then
    -- Mode intentionally not cleared: loot window closes before the money transaction fires
  elseif event == "TRADE_SHOW" then
    Accountant_Mode = "TRADE"
  elseif event == "TRADE_CLOSE" then
    Accountant_Mode = ""
  elseif event == "QUEST_COMPLETE" then
    Accountant_Mode = "QUEST"
  elseif event == "QUEST_FINISHED" then
    -- Mode intentionally not cleared: quest window closes before the money transaction fires
  elseif event == "MAIL_SHOW" then
    Accountant_Mode = "MAIL"
  elseif event == "MAIL_CLOSED" then
    Accountant_Mode = ""
  elseif event == "TRAINER_SHOW" then
    Accountant_Mode = "TRAIN"
  elseif event == "TRAINER_CLOSED" then
    Accountant_Mode = ""
  elseif event == "AUCTION_HOUSE_SHOW" then
    Accountant_Mode = "AH"
  elseif event == "AUCTION_HOUSE_CLOSED" then
    Accountant_Mode = ""
  elseif event == "PLAYER_MONEY" then
    Accountant_UpdateLog()
  -- CHAT_MSG_MONEY is expected to fire before PLAYER_MONEY
  elseif event == "CHAT_MSG_MONEY" then
    Accountant_OnShareMoney(event, arg1)
  end
  if Accountant_Verbose and Accountant_Mode ~= oldmode then
    local modeName = Accountant_Mode ~= "" and Accountant_Mode or ACCLOC_OTHER
    ACC_Print(ACCLOC_VERBOSE_MODE .. " '" .. modeName .. "'")
  end
end

function Accountant_OnShareMoney(event, arg1)
  local gold, silver, copper, money, oldMode

  -- Parse the message for money gained
  _, _, gold = string.find(arg1, "(%d+) " .. GOLD)
  _, _, silver = string.find(arg1, "(%d+) " .. SILVER)
  _, _, copper = string.find(arg1, "(%d+) " .. COPPER)
  gold = tonumber(gold) or 0
  silver = tonumber(silver) or 0
  copper = tonumber(copper) or 0
  money = copper + silver * 100 + gold * 10000

  oldMode = Accountant_Mode
  if not Accountant_LastMoney then
    Accountant_LastMoney = 0
  end

  -- Force a money update with the calculated shared amount
  Accountant_LastMoney = Accountant_LastMoney - money
  Accountant_Mode = "LOOT"
  Accountant_UpdateLog()
  Accountant_Mode = oldMode

  -- Suppress the incoming PLAYER_MONEY event for this amount
  Accountant_LastMoney = Accountant_LastMoney + money
end

function Accountant_NiceCash(amount)
  local agold = 10000
  local asilver = 100
  local outstr = ""
  local gold = 0
  local silver = 0

  if amount >= agold then
    gold = math.floor(amount / agold)
    outstr = "|cFFFFFF00" .. gold .. "g "
  end
  amount = amount - (gold * agold)
  if amount >= asilver then
    silver = math.floor(amount / asilver)
    outstr = outstr .. "|cFFCCCCCC" .. silver .. "s "
  end
  amount = amount - (silver * asilver)
  if amount > 0 then
    outstr = outstr .. "|cFFFF6600" .. amount .. "c"
  end
  return outstr
end

function Accountant_WeekStart()
  local oneday = 86400
  local ct = time()
  local dt = date("*t", ct)
  local thisDay = dt["wday"]
  while thisDay ~= Accountant_SaveData[Accountant_Player]["options"].weekstart do
    ct = ct - oneday
    dt = date("*t", ct)
    thisDay = dt["wday"]
  end
  local cdate = date(nil, ct)
  return string.sub(cdate, 0, 8)
end

function Accountant_OnShow()
  Accountant_SetLabels()
  if Accountant_CurrentTab ~= 5 then
    local totalIn = 0
    local totalOut = 0
    local mode = Accountant_LogModes[Accountant_CurrentTab]
    for key, value in pairs(Accountant_Data) do
      local rowIn = getglobal("AccountantFrameRow" .. Accountant_Data[key].InPos .. "In")
      rowIn:SetText(Accountant_NiceCash(Accountant_Data[key][mode].In))
      totalIn = totalIn + Accountant_Data[key][mode].In

      local rowOut = getglobal("AccountantFrameRow" .. Accountant_Data[key].InPos .. "Out")
      rowOut:SetText(Accountant_NiceCash(Accountant_Data[key][mode].Out))
      totalOut = totalOut + Accountant_Data[key][mode].Out
    end

    AccountantFrameTotalInValue:SetText(Accountant_NiceCash(totalIn))
    AccountantFrameTotalOutValue:SetText(Accountant_NiceCash(totalOut))
    if totalOut > totalIn then
      local diff = totalOut - totalIn
      AccountantFrameTotalFlow:SetText("|cFFFF3333" .. ACCLOC_NETLOSS .. ":")
      AccountantFrameTotalFlowValue:SetText(Accountant_NiceCash(diff))
    elseif totalOut ~= totalIn then
      local diff = totalIn - totalOut
      AccountantFrameTotalFlow:SetText("|cFF00FF00" .. ACCLOC_NETPROF .. ":")
      AccountantFrameTotalFlowValue:SetText(Accountant_NiceCash(diff))
    else
      AccountantFrameTotalFlow:SetText(ACCLOC_NET)
      AccountantFrameTotalFlowValue:SetText("")
    end
  else
    -- Character totals tab
    local alltotal = 0
    local i = 1
    for char, charvalue in pairs(Accountant_SaveData) do
      if char ~= "last_saved" then
        getglobal("AccountantFrameRow" .. i .. "Title"):SetText(char)
        if Accountant_SaveData[char]["options"]["totalcash"] ~= nil then
          getglobal("AccountantFrameRow" .. i .. "In"):SetText(
            Accountant_NiceCash(Accountant_SaveData[char]["options"]["totalcash"])
          )
          alltotal = alltotal + Accountant_SaveData[char]["options"]["totalcash"]
          getglobal("AccountantFrameRow" .. i .. "Out"):SetText(Accountant_SaveData[char]["options"]["date"])
        else
          getglobal("AccountantFrameRow" .. i .. "In"):SetText(ACCLOC_UNKNOWN)
        end
        i = i + 1
      end
    end
    AccountantFrameTotalInValue:SetText(Accountant_NiceCash(alltotal))
  end
  SetPortraitTexture(AccountantFramePortrait, "player")

  if Accountant_CurrentTab == 3 then
    AccountantFrameExtra:SetText(ACCLOC_WEEKSTART .. ":")
    AccountantFrameExtraValue:SetText(Accountant_SaveData[Accountant_Player]["options"]["dateweek"])
  else
    AccountantFrameExtra:SetText("")
    AccountantFrameExtraValue:SetText("")
  end

  PanelTemplates_SetTab(AccountantFrame, Accountant_CurrentTab)
end

function Accountant_OnHide()
  if MYADDONS_ACTIVE_OPTIONSFRAME == AccountantFrame then
    ShowUIPanel(myAddOnsFrame)
  end
end

function ACC_Print(msg)
  DEFAULT_CHAT_FRAME:AddMessage(msg)
end

function Accountant_ShowUsage()
  ACC_Print("/accountant log")
  ACC_Print("/accountant verbose")
  ACC_Print("/accountant week")
end

function Accountant_ResetData()
  local resetType = Accountant_LogModes[Accountant_CurrentTab]
  if resetType == "Total" then
    resetType = "overall"
  end
  StaticPopupDialogs["ACCOUNTANT_RESET"].text = ACCLOC_RESET_CONF .. " " .. resetType .. " " .. ACCLOC_TOTAL .. "?"
  StaticPopup_Show("ACCOUNTANT_RESET")
end

function Accountant_ResetConfirmed()
  local resetType = Accountant_LogModes[Accountant_CurrentTab]
  for key, value in pairs(Accountant_Data) do
    Accountant_Data[key][resetType].In = 0
    Accountant_Data[key][resetType].Out = 0
    Accountant_SaveData[Accountant_Player]["data"][key][resetType].In = 0
    Accountant_SaveData[Accountant_Player]["data"][key][resetType].Out = 0
  end
  if AccountantFrame:IsVisible() then
    Accountant_OnShow()
  end
end

function Accountant_CheckDate()
  local cdate = date()
  cdate = string.sub(cdate, 0, 8)

  -- Check if the calendar day has changed
  if Accountant_SaveData[Accountant_Player]["options"]["date"] ~= cdate then
    for mode, value in pairs(Accountant_Data) do
      Accountant_Data[mode]["Day"].In = 0
      Accountant_SaveData[Accountant_Player]["data"][mode]["Day"].In = 0
      Accountant_Data[mode]["Day"].Out = 0
      Accountant_SaveData[Accountant_Player]["data"][mode]["Day"].Out = 0
    end
    Accountant_SaveData[Accountant_Player]["options"]["date"] = cdate
  end

  -- Check if the week has rolled over
  if Accountant_SaveData[Accountant_Player]["options"]["dateweek"] ~= Accountant_WeekStart() then
    for mode, value in pairs(Accountant_Data) do
      Accountant_Data[mode]["Week"].In = 0
      Accountant_SaveData[Accountant_Player]["data"][mode]["Week"].In = 0
      Accountant_Data[mode]["Week"].Out = 0
      Accountant_SaveData[Accountant_Player]["data"][mode]["Week"].Out = 0
    end
    Accountant_SaveData[Accountant_Player]["options"]["dateweek"] = Accountant_WeekStart()
  end
end

function Accountant_UpdateLog()
  Accountant_CheckDate()

  Accountant_CurrentMoney = GetMoney()
  Accountant_SaveData[Accountant_Player]["options"].totalcash = Accountant_CurrentMoney
  local diff = Accountant_CurrentMoney - Accountant_LastMoney
  Accountant_LastMoney = Accountant_CurrentMoney

  if diff == nil or diff == 0 then
    return
  end

  local mode = Accountant_Mode
  if mode == "" then
    mode = "OTHER"
  end

  if diff > 0 then
    for key, logmode in pairs(Accountant_LogModes) do
      Accountant_Data[mode][logmode].In = Accountant_Data[mode][logmode].In + diff
      Accountant_SaveData[Accountant_Player]["data"][mode][logmode].In = Accountant_Data[mode][logmode].In
    end
    if Accountant_Verbose then
      ACC_Print(ACCLOC_GAINED .. " " .. Accountant_NiceCash(diff) .. " " .. ACCLOC_FROM .. " " .. mode)
    end
  elseif diff < 0 then
    diff = diff * -1
    for key, logmode in pairs(Accountant_LogModes) do
      Accountant_Data[mode][logmode].Out = Accountant_Data[mode][logmode].Out + diff
      Accountant_SaveData[Accountant_Player]["data"][mode][logmode].Out = Accountant_Data[mode][logmode].Out
    end
    if Accountant_Verbose then
      ACC_Print(ACCLOC_LOST .. " " .. Accountant_NiceCash(diff) .. " " .. ACCLOC_FROM .. " " .. mode)
    end
  end

  -- Repair costs are tracked separately but fall under merchant category afterward
  if Accountant_Mode == "REPAIRS" then
    Accountant_Mode = "MERCH"
  end

  if AccountantFrame:IsVisible() then
    Accountant_OnShow()
  end
end

function AccountantTab_OnClick(tab)
  PanelTemplates_SetTab(AccountantFrame, tab:GetID())
  Accountant_CurrentTab = tab:GetID()
  PlaySound("igCharacterInfoTab")
  Accountant_OnShow()
end

-- Hooks

function Accountant_RepairAllItems()
  Accountant_Mode = "REPAIRS"
  Accountant_RepairAllItems_old()
end

function Accountant_CursorHasItem()
  if InRepairMode() then
    Accountant_Mode = "REPAIRS"
  end
  return Accountant_CursorHasItem_old()
end

-- ---------------------------------------------------------------------------
-- Frame Creation
-- Replaces Accountant.xml. All frames are created at load time.
-- ---------------------------------------------------------------------------

local function Accountant_CreateFrames()
  -- Main window
  local f = CreateFrame("Frame", "AccountantFrame", UIParent)
  f:SetWidth(384)
  f:SetHeight(514)
  f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 400, -104)
  f:SetToplevel(true)
  f:EnableMouse(true)
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:Hide()

  f:SetScript("OnDragStart", function()
    AccountantFrame:StartMoving()
  end)
  f:SetScript("OnDragStop", function()
    AccountantFrame:StopMovingOrSizing()
  end)
  f:SetScript("OnMouseUp", function()
    AccountantFrame:StopMovingOrSizing()
  end)
  f:SetScript("OnShow", function()
    Accountant_OnShow()
  end)
  f:SetScript("OnHide", function()
    Accountant_OnHide()
  end)
  f:SetScript("OnEvent", function()
    Accountant_OnEvent(event)
  end)

  tinsert(UISpecialFrames, "AccountantFrame")
  UIPanelWindows["AccountantFrame"] = { area = "left", pushable = 11 }

  Accountant_RegisterEvents(f)

  -- Background portrait texture
  local portrait = f:CreateTexture("AccountantFramePortrait", "BACKGROUND")
  portrait:SetWidth(60)
  portrait:SetHeight(60)
  portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 7, -6)

  -- Artwork textures
  local texTopLeft = f:CreateTexture("AccountantFrameTopLeft", "ARTWORK")
  texTopLeft:SetWidth(256)
  texTopLeft:SetHeight(256)
  texTopLeft:SetPoint("TOPLEFT", f, "TOPLEFT")
  texTopLeft:SetTexture("Interface\\AddOns\\Accountant\\img\\AccountantFrame-TopLeft")

  local texTopRight = f:CreateTexture("AccountantFrameTopRight", "ARTWORK")
  texTopRight:SetWidth(128)
  texTopRight:SetHeight(256)
  texTopRight:SetPoint("TOPRIGHT", f, "TOPRIGHT")
  texTopRight:SetTexture("Interface\\AddOns\\Accountant\\img\\AccountantFrame-TopRight")

  local texBotLeft = f:CreateTexture("AccountantFrameBotLeft", "ARTWORK")
  texBotLeft:SetWidth(256)
  texBotLeft:SetHeight(256)
  texBotLeft:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -256)
  texBotLeft:SetTexture("Interface\\AddOns\\Accountant\\img\\AccountantFrame-BotLeft")

  local texBotRight = f:CreateTexture("AccountantFrameBotRight", "ARTWORK")
  texBotRight:SetWidth(128)
  texBotRight:SetHeight(256)
  texBotRight:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -256)
  texBotRight:SetTexture("Interface\\AddOns\\Accountant\\img\\AccountantFrame-BotRight")

  -- Title text
  local title = f:CreateFontString("AccountantFrameTitleText", "ARTWORK", "GameFontHighlight")
  title:SetWidth(300)
  title:SetHeight(14)
  title:SetPoint("TOP", f, "TOP", 0, -16)

  -- Column headers
  local colSource = f:CreateFontString("AccountantFrameSource", "ARTWORK", "GameFontHighlight")
  colSource:SetPoint("TOPLEFT", f, "TOPLEFT", 24, -93)

  local colIn = f:CreateFontString("AccountantFrameIn", "ARTWORK", "GameFontHighlight")
  colIn:SetPoint("TOP", f, "TOPLEFT", 204, -93)

  local colOut = f:CreateFontString("AccountantFrameOut", "ARTWORK", "GameFontHighlight")
  colOut:SetPoint("TOP", f, "TOPLEFT", 295, -93)

  -- Summary labels and values
  local totalIn = f:CreateFontString("AccountantFrameTotalIn", "ARTWORK", "GameFontHighlightSmall")
  totalIn:SetPoint("TOPLEFT", f, "TOPLEFT", 75, -39)

  local totalInVal = f:CreateFontString("AccountantFrameTotalInValue", "ARTWORK", "GameFontHighlightSmall")
  totalInVal:SetPoint("TOPLEFT", f, "TOPLEFT", 163, -39)

  local totalOut = f:CreateFontString("AccountantFrameTotalOut", "ARTWORK", "GameFontHighlightSmall")
  totalOut:SetPoint("TOPLEFT", f, "TOPLEFT", 75, -55)

  local totalOutVal = f:CreateFontString("AccountantFrameTotalOutValue", "ARTWORK", "GameFontHighlightSmall")
  totalOutVal:SetPoint("TOPLEFT", f, "TOPLEFT", 163, -55)

  local totalFlow = f:CreateFontString("AccountantFrameTotalFlow", "ARTWORK", "GameFontHighlightSmall")
  totalFlow:SetPoint("TOPLEFT", f, "TOPLEFT", 75, -71)

  local totalFlowVal = f:CreateFontString("AccountantFrameTotalFlowValue", "ARTWORK", "GameFontHighlightSmall")
  totalFlowVal:SetPoint("TOPLEFT", f, "TOPLEFT", 163, -71)

  local extra = f:CreateFontString("AccountantFrameExtra", "ARTWORK", "GameFontHighlightSmall")
  extra:SetPoint("TOP", f, "TOPLEFT", 310, -39)

  local extraVal = f:CreateFontString("AccountantFrameExtraValue", "ARTWORK", "GameFontNormalSmall")
  extraVal:SetPoint("TOP", extra, "BOTTOM", 0, 0)

  -- Data rows
  local prevRow = nil
  for i = 1, 15 do
    local row = CreateFrame("Frame", "AccountantFrameRow" .. i, f)
    row:SetWidth(320)
    row:SetHeight(19)
    if i == 1 then
      row:SetPoint("TOPLEFT", f, "TOPLEFT", 21, -111)
    else
      row:SetPoint("TOPLEFT", prevRow, "BOTTOMLEFT", 0, -1)
    end

    local rowTitle = row:CreateFontString("AccountantFrameRow" .. i .. "Title", "BACKGROUND", "GameFontNormal")
    rowTitle:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -2)

    local rowIn = row:CreateFontString("AccountantFrameRow" .. i .. "In", "BACKGROUND", "GameFontHighlightSmall")
    rowIn:SetPoint("TOPRIGHT", row, "TOPLEFT", 225, -4)

    local rowOut = row:CreateFontString("AccountantFrameRow" .. i .. "Out", "BACKGROUND", "GameFontHighlightSmall")
    rowOut:SetPoint("TOPRIGHT", row, "TOPLEFT", 317, -4)

    prevRow = row
  end

  -- Close button
  local closeBtn = CreateFrame("Button", "AccountantFrameCloseButton", f, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", f, "TOPRIGHT", -30, -8)

  -- Exit button
  local exitBtn = CreateFrame("Button", "AccountantFrameExitButton", f, "UIPanelButtonTemplate")
  exitBtn:SetWidth(77)
  exitBtn:SetHeight(21)
  exitBtn:SetPoint("BOTTOMRIGHT", texBotRight, "BOTTOMRIGHT", -43, 81)
  exitBtn:SetText(ACCLOC_EXIT)
  exitBtn:SetScript("OnClick", function()
    HideUIPanel(AccountantFrame)
  end)

  -- Options button
  local optsBtn = CreateFrame("Button", "AccountantFrameOptionsButton", f, "UIPanelButtonTemplate")
  optsBtn:SetWidth(80)
  optsBtn:SetHeight(22)
  optsBtn:SetPoint("TOPRIGHT", exitBtn, "TOPLEFT", 0, 0)
  optsBtn:SetText(ACCLOC_OPTBUT)
  optsBtn:SetScript("OnClick", function()
    AccountantOptions_Toggle()
  end)

  -- Reset button
  local resetBtn = CreateFrame("Button", "AccountantFrameResetButton", f, "UIPanelButtonTemplate")
  resetBtn:SetWidth(60)
  resetBtn:SetHeight(22)
  resetBtn:SetPoint("TOP", f, "TOPLEFT", 310, -62)
  resetBtn:SetText(ACCLOC_RESET)
  resetBtn:SetScript("OnClick", function()
    Accountant_ResetData()
  end)

  -- Money frame
  local moneyFrame = CreateFrame("Frame", "AccountantMoneyFrame", f, "SmallMoneyFrameTemplate")
  moneyFrame:SetPoint("TOPRIGHT", f, "BOTTOMLEFT", 180, 100)

  -- Tabs
  local tabAnchors = {
    { point = "BOTTOMLEFT", relativeTo = f, relativePoint = "BOTTOMLEFT", x = 15, y = 46 },
    { point = "LEFT", relativeTo = nil, relativePoint = "RIGHT", x = -15, y = 0 },
    { point = "LEFT", relativeTo = nil, relativePoint = "RIGHT", x = -15, y = 0 },
    { point = "LEFT", relativeTo = nil, relativePoint = "RIGHT", x = -15, y = 0 },
    { point = "BOTTOMRIGHT", relativeTo = f, relativePoint = "BOTTOMRIGHT", x = -40, y = 46 },
  }
  local prevTab = nil
  for i = 1, 5 do
    local tab = CreateFrame("Button", "AccountantFrameTab" .. i, f, "CharacterFrameTabButtonTemplate")
    tab:SetID(i)
    local a = tabAnchors[i]
    local relTo = a.relativeTo or prevTab
    tab:SetPoint(a.point, relTo, a.relativePoint, a.x, a.y)
    tab:SetScript("OnClick", function()
      AccountantTab_OnClick(tab)
    end)
    prevTab = tab
  end

  -- Tooltip
  CreateFrame("GameTooltip", "AccountantTooltip", UIParent, "GameTooltipTemplate")
end

Accountant_CreateFrames()
