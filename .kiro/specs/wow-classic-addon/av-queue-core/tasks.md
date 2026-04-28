# Implementation Plan: AVQueueHelper WoW Classic Addon

## Overview

Implement a WoW Classic Lua addon that streamlines Alterac Valley battleground queuing via three F12 keypresses. The addon uses secure action buttons with keybind rebinding, a six-state state machine, event-driven step transitions, and a queue-pop alert system with sound and screen flash. Supports both Alliance and Horde factions. Implementation follows a two-file structure: AVQueueHelper.toc and AVQueueHelper.lua.

## Tasks

- [x] 1. Create addon file structure and constants
  - [x] 1.1 Create AVQueueHelper.toc
    - Define Interface version (11503), Title, Notes, Author, Version, and list AVQueueHelper.lua
    - _Requirements: 2.1_

  - [x] 1.2 Define constants and configuration in AVQueueHelper.lua
    - Define STATE enum (IDLE, TARGETING, INTERACTING, GOSSIPING, QUEUING, READY)
    - Define LOG_LEVEL enum (DEBUG, INFO, WARN, ERROR)
    - Define NPC_NAMES table (Alliance → Stormpike Emissary, Horde → Frostwolf Emissary)
    - Define CONFIG table (NPC_NAME, STEP_DELAY=0.2, TIMEOUT=6, KEYBIND=F12, MSG_PREFIX, ALERT_SOUND=1018, ALERT_INTERVAL=3, LOG_LEVEL=INFO)
    - Initialize addonState table (currentState, timeoutTimer, stepTimer, generation, alertTimer, flashTimer)
    - _Requirements: 1.1, 6.1, 8.1, 8.2_

- [x] 2. Implement event framework and logging
  - [x] 2.1 Create event dispatch framework
    - Create invisible Frame (AVQueueHelperFrame) via CreateFrame
    - Register GOSSIP_SHOW, BATTLEFIELDS_SHOW, UPDATE_BATTLEFIELD_STATUS events
    - Set up OnEvent script dispatching to eventHandlers table
    - _Requirements: 7.1_

  - [x] 2.2 Implement PrintMessage logging utility
    - Accept msg and optional level parameter (default INFO)
    - Filter messages below CONFIG.LOG_LEVEL
    - Output to DEFAULT_CHAT_FRAME with green prefix |cFF00FF00[AVQueueHelper]|r
    - _Requirements: 8.1, 8.2, 8.3_

- [x] 3. Implement state management and timeout
  - [x] 3.1 Implement state accessors and reset
    - Implement GetState(), SetState(newState)
    - Implement ResetState(): cancel stepTimer, cancel timeoutTimer, stop alert sound, stop flash, increment generation, set IDLE, rebind F12 → AVQueueHelperButton
    - _Requirements: 6.1, 6.4, 6.5_

  - [x] 3.2 Implement timeout mechanism
    - Implement StartTimeout(): start 6-second C_Timer.NewTimer that prints timeout message and calls ResetState
    - Implement CancelTimeout(): cancel timeout timer
    - _Requirements: 6.2, 6.3_

- [x] 4. Implement alert system
  - [x] 4.1 Implement alert sound
    - Implement StartAlertSound(): play Sound Kit 1018 immediately, start C_Timer.NewTicker every 3 seconds
    - Implement StopAlertSound(): cancel ticker
    - Ticker self-stops if state is no longer READY
    - _Requirements: 5.3_

  - [x] 4.2 Implement screen flash
    - Create AVQueueHelperFlashFrame (TOOLTIP strata, full-screen, red texture alpha 0.3)
    - Implement StartFlash(): show frame, start 0.5s toggle ticker
    - Implement StopFlash(): cancel ticker, hide frame
    - _Requirements: 5.4_

- [x] 5. Implement event handlers
  - [x] 5.1 Implement GOSSIP_SHOW handler
    - Guard: only respond when state is INTERACTING
    - Rebind F12 back to AVQueueHelperButton
    - After 0.2s delay (with generation check): set state to GOSSIPING, call SelectGossipOption(1)
    - _Requirements: 3.4, 7.2_

  - [x] 5.2 Implement BATTLEFIELDS_SHOW handler
    - Guard: only respond when state is GOSSIPING
    - Set state to QUEUING, rebind F12 → AVQueueHelperJoinButton
    - Print prompt to press F12 to join queue
    - _Requirements: 3.5, 7.3_

  - [x] 5.3 Implement UPDATE_BATTLEFIELD_STATUS handler
    - When state is READY: check if any slot still "confirm"; if none, print expired message and ResetState
    - When state is IDLE: scan slots 1-3 for "confirm"; if found, enter READY state with alerts and rebind F12 → EnterButton
    - Ignore event in all other states
    - _Requirements: 5.1, 5.2, 5.5, 5.7, 7.4, 7.5, 7.6_

- [x] 6. Implement secure buttons and queue flow
  - [x] 6.1 Create target button (AVQueueHelperButton)
    - SecureActionButtonTemplate with type=macro, macrotext set on PLAYER_LOGIN to /target <NPC>
    - PostClick: guard state==IDLE, check battlefield status (queued/active/ended), start timeout, verify UnitName matches NPC, rebind F12 → INTERACTTARGET or ResetState on failure
    - _Requirements: 2.2, 3.1, 3.2, 3.3, 4.1, 4.2, 4.3, 4.4_

  - [x] 6.2 Create join button (AVQueueHelperJoinButton)
    - SecureActionButtonTemplate with macrotext /click BattlefieldFrameJoinButton
    - PostClick: guard state==QUEUING, print queue complete, ResetState
    - _Requirements: 3.6_

  - [x] 6.3 Create enter button (AVQueueHelperEnterButton)
    - SecureActionButtonTemplate with macrotext /click PVPReadyDialogEnterBattleButton
    - PostClick: guard state==READY, print entering battleground, ResetState
    - _Requirements: 5.6_

- [x] 7. Implement initialization (PLAYER_LOGIN)
  - [x] 7.1 Implement PLAYER_LOGIN handler
    - Detect faction via UnitFactionGroup("player"), set CONFIG.NPC_NAME from NPC_NAMES
    - Handle unknown faction: warn and default to Alliance
    - Set targetBtn macrotext to /target <NPC>
    - Bind F12 → AVQueueHelperButton via SetBindingClick
    - Print initialization message with faction info
    - Unregister PLAYER_LOGIN after first run
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 2.1, 2.3, 2.4_

## Notes

- All code is Lua targeting the WoW Classic client API (Interface 11503)
- Single-file architecture: AVQueueHelper.lua + AVQueueHelper.toc
- No external build tools, package managers, or test frameworks — addon runs directly in the WoW client
- Protected API constraints require three separate hardware-event keypresses; the addon cannot fully automate the flow in a single press
- Generation counter prevents stale timer callbacks from executing after state resets
