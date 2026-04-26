# Implementation Plan: AVAutoQueue WoW Classic Addon

## Overview

Implement a WoW Classic Lua addon that automates Alterac Valley battleground queuing via a single F12 keypress. The addon uses a state machine driven by game events and C_Timer.After delays to sequentially target the NPC, interact, select gossip, and join the queue. Implementation follows a two-file structure: AVAutoQueue.toc and AVAutoQueue.lua.

## Tasks

- [x] 1. Create addon file structure and TOC
  - [x] 1.1 Create the AVAutoQueue.toc file
    - Define Interface version, addon Title, Notes, and list AVAutoQueue.lua as the loaded file
    - _Requirements: 1.1_

  - [x] 1.2 Create AVAutoQueue.lua with configuration constants and state definitions
    - Define the STATE enum table (IDLE, TARGETING, INTERACTING, GOSSIPING, QUEUING)
    - Define the CONFIG table (NPC_NAME, STEP_DELAY, TIMEOUT, MSG_PREFIX)
    - Initialize the addonState table (currentState, timeoutTimer, stepTimer)
    - _Requirements: 6.1_

- [x] 2. Implement core frame and event registration
  - [x] 2.1 Create the core event frame and register events
    - Create an invisible Frame via CreateFrame("Frame", "AVAutoQueueFrame", UIParent)
    - Register GOSSIP_SHOW and BATTLEFIELDS_SHOW events
    - Set up OnEvent script to dispatch events to handler functions
    - _Requirements: 7.1, 7.2_

  - [x] 2.2 Implement the message output utility function
    - Implement PrintMessage(msg) that outputs prefixed messages to DEFAULT_CHAT_FRAME
    - Use CONFIG.MSG_PREFIX for the green-colored addon tag
    - _Requirements: 2.3, 3.3, 4.3, 5.2, 5.3_

- [x] 3. Implement state management and timeout logic
  - [x] 3.1 Implement state management functions
    - Implement GetState(), SetState(newState), and ResetState()
    - ResetState must cancel any pending stepTimer and timeoutTimer, then set state to IDLE
    - _Requirements: 6.1, 6.2, 6.3_

  - [x] 3.2 Implement global timeout mechanism
    - Implement StartTimeout() that starts a 15-second C_Timer.After which calls ResetState and prints timeout message
    - Implement CancelTimeout() to cancel the timeout timer
    - StartTimeout should be called when the process begins; CancelTimeout on success or reset
    - _Requirements: 6.4, 8.6_

- [x] 4. Checkpoint - Verify foundation
  - Ensure the addon loads without errors in WoW Classic. Verify state variables initialize correctly and the frame registers events. Ask the user if questions arise.

- [x] 5. Implement the queuing workflow steps
  - [x] 5.1 Implement the keybinding and process entry function
    - Create AVAutoQueue_StartProcess() as the F12 handler
    - Check if currentState is IDLE; if not, ignore the keypress (re-entrancy guard)
    - If IDLE, set state to TARGETING, call StartTimeout(), and invoke TargetNPC()
    - Register F12 keybinding using SetBindingClick or a Bindings.xml approach
    - _Requirements: 1.1, 1.2, 1.3, 2.1_

  - [x] 5.2 Implement the target NPC module
    - Implement TargetNPC() that executes TargetUnit("Stormpike Emissary") or equivalent macro
    - Verify target via UnitName("target") == CONFIG.NPC_NAME
    - On success: wait STEP_DELAY via C_Timer.After, then set state to INTERACTING and call InteractWithTarget()
    - On failure: print error message "未找到 Stormpike Emissary，请靠近该 NPC 后重试" and call ResetState()
    - _Requirements: 2.1, 2.2, 2.3, 8.1, 8.3_

  - [x] 5.3 Implement the NPC interaction module
    - Implement InteractWithTarget() that calls InteractUnit("target")
    - The actual continuation is driven by the GOSSIP_SHOW event handler (not a direct callback)
    - _Requirements: 3.1, 3.3_

  - [x] 5.4 Implement the GOSSIP_SHOW event handler
    - In the OnEvent dispatcher, handle GOSSIP_SHOW when state is INTERACTING
    - On event: wait STEP_DELAY via C_Timer.After, then set state to GOSSIPING and call SelectFirstGossipOption()
    - Ignore the event if state is not INTERACTING (idle guard)
    - _Requirements: 3.2, 7.1, 7.3, 7.5, 8.1, 8.4_

  - [x] 5.5 Implement the gossip selection module
    - Implement SelectFirstGossipOption() that calls SelectGossipOption(1) or C_GossipInfo.SelectOption(1)
    - The continuation is driven by the BATTLEFIELDS_SHOW event handler
    - _Requirements: 4.1, 4.3_

  - [x] 5.6 Implement the BATTLEFIELDS_SHOW event handler
    - In the OnEvent dispatcher, handle BATTLEFIELDS_SHOW when state is GOSSIPING
    - On event: wait STEP_DELAY via C_Timer.After, then set state to QUEUING and call JoinBattleQueue()
    - Ignore the event if state is not GOSSIPING (idle guard)
    - _Requirements: 5.1, 7.2, 7.4, 7.5, 8.1, 8.5_

  - [x] 5.7 Implement the battlefield join module
    - Implement JoinBattleQueue() that calls JoinBattlefield(0)
    - On success: print "已成功加入战场排队" and call ResetState() (with CancelTimeout)
    - On failure: print "无法加入战场排队，请手动操作" and call ResetState()
    - _Requirements: 5.1, 5.2, 5.3, 6.3_

- [x] 6. Checkpoint - Full flow verification
  - Ensure the complete F12 → target → interact → gossip → join flow works end-to-end. Verify timeout resets state after 15 seconds. Verify re-entrancy guard blocks duplicate F12 presses during execution. Ask the user if questions arise.

- [x] 7. Wire keybinding and finalize
  - [x] 7.1 Set up F12 keybinding registration
    - If using Bindings.xml: create the XML file, reference it in the TOC, and bind to AVAutoQueue_StartProcess
    - If using SetBinding in code: register the binding on PLAYER_LOGIN or ADDON_LOADED event
    - Ensure the binding persists across sessions or is re-registered on load
    - _Requirements: 1.1, 1.2_

  - [x] 7.2 Add step delay cancellation on reset
    - Ensure ResetState() properly cancels any pending C_Timer.After callbacks (stepTimer) to prevent stale callbacks from firing after a reset or timeout
    - _Requirements: 8.6_

- [x] 8. Final checkpoint - Complete addon validation
  - Ensure all tests pass, verify the addon loads cleanly, the full workflow executes correctly, timeout and error paths reset state properly, and F12 re-entrancy is blocked during execution. Ask the user if questions arise.

## Notes

- All code is written in Lua targeting the WoW Classic client API
- The addon uses a single-file architecture (AVAutoQueue.lua) plus the TOC descriptor
- No property-based tests are applicable since this is a game client addon with no testable pure logic outside the WoW runtime
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation at key milestones
