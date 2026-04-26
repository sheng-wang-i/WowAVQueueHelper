# Project Structure

```
├── AVQueueHelper.toc          # Addon descriptor (interface version, title, file list)
└── AVQueueHelper.lua          # All addon logic (single-file architecture)
```

## Architecture Pattern
- Single-file Lua addon with event-driven state machine
- No module system or external libraries — everything lives in `AVQueueHelper.lua`

## Code Organization (within AVQueueHelper.lua)
1. State enum (`STATE` table — IDLE, TARGETING, INTERACTING, GOSSIPING, QUEUING, READY)
2. Log levels (`LOG_LEVEL` table — DEBUG, INFO, WARN, ERROR)
3. Configuration constants (`CONFIG` table — NPC name, delays, timeout, message prefix, alert sound, alert interval, log level)
4. State variables (`addonState` table — currentState, timeoutTimer, stepTimer, generation, alertTimer, flashTimer)
5. Core event framework (event dispatch via `eventHandlers` table)
6. Utility functions (PrintMessage with log level, state management, timeout handling)
7. Alert functions (StartAlertSound/StopAlertSound using PlaySound + C_Timer.NewTicker)
8. Screen flash functions (StartFlash/StopFlash using a full-screen red texture + C_Timer.NewTicker)
9. Workflow step functions (SelectFirstGossipOption)
10. Event handlers (GOSSIP_SHOW, BATTLEFIELDS_SHOW, UPDATE_BATTLEFIELD_STATUS)
11. Secure buttons (AVQueueHelperButton, AVQueueHelperJumpButton, AVQueueHelperJoinButton, AVQueueHelperEnterButton)
12. Keybinding setup (F12 → AVQueueHelperButton on PLAYER_LOGIN)

## Conventions
- All global frame names use the `AVQueueHelper` prefix to avoid namespace collisions
- Local variables and functions are preferred over globals
- In-game chat messages use a colored prefix: `|cFF00FF00[AVQueueHelper]|r`
