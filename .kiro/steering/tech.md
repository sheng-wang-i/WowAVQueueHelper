# Tech Stack

## Language
- Lua (WoW Classic client runtime)

## Platform
- World of Warcraft Classic client API (WoW API)
- No external build tools, package managers, or dependencies
- All API and game resources should be based on WoW Classic English version, game version 1.15.*

## Key APIs
- `CreateFrame` — event listener frame creation and secure action buttons
- `C_Timer.After` / `C_Timer.NewTimer` / `C_Timer.NewTicker` — non-blocking delayed and repeating execution
- `InteractUnit` — NPC interaction
- `SelectGossipOption` / `C_GossipInfo.SelectOption` — gossip dialog selection
- `JoinBattlefield` — battleground queue entry
- `TargetUnit` / `UnitName` — NPC targeting and verification
- `GetBattlefieldStatus` / `GetBattlefieldWinner` / `LeaveBattlefield` — battleground status checks
- `DEFAULT_CHAT_FRAME:AddMessage` — player-facing messages
- `SetBindingClick` / `SetBinding` — runtime keybinding registration
- `PlaySound` — sound playback by Sound Kit ID
- `SetColorTexture` — creating colored textures for visual effects
- Never use functions that are only allowed in Blizzard UI but not allowed in addons

## Addon Structure
- `.toc` file — addon metadata and file manifest (Interface version, Title, Notes)
- `.lua` file — all addon logic in a single file

## Commands
There is no build or compile step. The addon is loaded directly by the WoW Classic client from the `Interface/AddOns/AVQueueHelper/` directory.

To "install" during development, copy or symlink the `AVQueueHelper/` folder into the WoW Classic AddOns directory:
```
<WoW Install>/Interface/AddOns/AVQueueHelper/
```

Reload in-game with `/reload` to pick up changes.
