# Accountant

Tracks your incoming and outgoing gold across multiple time periods and categories.

## Description

Accountant monitors every copper that enters or leaves your character and sorts it by source — looting mobs, completing quests, trading, using the auction house, paying for repairs, and more. Totals are broken down across four time periods so you can see exactly where your gold is coming from and going to, whether you're checking a single session or your all-time record.

A character summary tab shows the current gold holdings of every character on your account that has run Accountant, along with when that figure was last updated.

## Requirements

World of Warcraft client version 1.12.x (vanilla).

## Installation

1. Download and unzip the package.
2. Place the `Accountant` folder inside your `World of Warcraft/Interface/AddOns/` directory.
3. Launch the game and make sure Accountant is enabled on the character select screen.

## Usage

### Opening the window

Click the minimap button, or use a slash command:

| Command                 | Description                                                         |
| ----------------------- | ------------------------------------------------------------------- |
| `/accountant` or `/acc` | Open the Accountant window                                          |
| `/accountant verbose`   | Toggle verbose mode (prints each transaction to chat as it happens) |
| `/accountant week`      | Print the start date of the current tracking week to chat           |

### Tabs

The window has five tabs:

- **Session** — gold gained and spent since you last logged in
- **Day** — resets at midnight each day
- **Week** — resets on a configurable weekday
- **Total** — all-time cumulative totals
- **All Chars** — current gold and last-updated date for every character on your account

### Categories

Accountant tracks transactions under the following categories:

| Category       | What it covers                                                      |
| -------------- | ------------------------------------------------------------------- |
| Loot           | Coin looted from mobs and chests, plus gold shared by party members |
| Quest Rewards  | Gold received on quest completion                                   |
| Merchants      | Buying and selling items at vendors                                 |
| Repair Costs   | Item repair costs, tracked separately before rolling into Merchants |
| Training Costs | Ability and skill training at class trainers                        |
| Auction House  | Auction deposits, posting fees, and sale proceeds                   |
| Trade Window   | Gold exchanged via the player trade window                          |
| Mail           | Gold sent and received through the in-game mail system              |
| Taxi Fares     | Flight path costs                                                   |
| Unknown        | Any transaction that could not be attributed to a specific source   |

Each category shows a separate **In** and **Out** column, with a net profit or loss total at the top.

### Resetting data

Each tab (except All Chars) has a **Reset** button that clears the data for that time period only after a confirmation prompt.

## Options

Open the options panel via the **Options** button in the Accountant window.

| Option                  | Description                                                 |
| ----------------------- | ----------------------------------------------------------- |
| Show Minimap Button     | Toggle the minimap icon on or off                           |
| Minimap Button Position | Drag the slider to reposition the button around the minimap |
| Start of Week           | Choose which weekday the weekly totals reset on             |

## Localization

Accountant includes translations for the following languages:

- English (default)
- German — _snj & JokerGermany_
- Spanish — _jsr1976_
- French — _Thi0u_

## Credits

- **Sabaki** — original author
- **Shadow & Rophy** — additional development, party gold sharing (v2.2)
- **Losimagic, Shrill, Fillet** — testing
- **Razark** — minimap icon code (via Atlas)
- **terdong** — reset logic fix
