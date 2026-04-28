---
inclusion: always
---

# Product

AVQueueHelper is a World of Warcraft Classic addon that automates Alterac Valley battleground queuing for Alliance players. It streamlines the multi-step NPC interaction into a repeating F12 keypress flow.

## User-Facing Behavior

The player presses F12 three times in sequence to complete the full queue process:

1. F12 (press 1): Targets the "Stormpike Emissary" NPC via a secure macro button.
2. F12 (press 2): Interacts with the targeted NPC (bound to INTERACTTARGET). The addon automatically selects the first gossip option when the dialog opens.
3. F12 (press 3): Clicks the Blizzard "Join Battle" button to enter the battleground queue.

Between presses the addon provides chat feedback so the player knows what to do next.

## Battleground Status Handling

- If already queued (`status == "queued"`), pressing F12 prints a message and does nothing else.
- If inside an active battleground (`status == "active"`), pressing F12 checks if the match is over and auto-leaves if safe, otherwise prints a status message.
- When the queue pops (`status == "confirm"`), the addon enters READY state: rebinds F12 to the enter button, plays a repeating alert sound (Sound ID 1018, every 3 seconds), and flashes the screen red until the player enters or the confirm expires.

## Key Constraints

- Protected API functions (TargetUnit, InteractUnit, JoinBattlefield) require a hardware event, so each step must be triggered by a real keypress — the addon cannot fully automate the flow in a single press.
- The addon rebinds F12 at each stage to the appropriate secure action, then resets it back to the initial target button on completion or timeout.
- A configurable global timeout (CONFIG.TIMEOUT, default 6 s) cancels the flow and resets state if the player stalls.
- Step delays (CONFIG.STEP_DELAY, default 0.2 s) space out automated actions like gossip option selection.
- A generation counter prevents stale timers from executing after a reset.

## Logging

- All messages go through `PrintMessage(msg, level)` with a configurable log level (DEBUG, INFO, WARN, ERROR).
- `CONFIG.LOG_LEVEL` controls the minimum level that gets printed (default: INFO).
- Messages use the colored prefix `|cFF00FF00[AVQueueHelper]|r`.

## Audience & Faction

- Alliance only. The NPC name ("Stormpike Emissary") is hardcoded in CONFIG.NPC_NAME.

## Language
- Only english can be used in lua file, toc file.

## Product Conventions

- The addon must never silently fail — every state transition or error should produce a chat message.
- On any failure or timeout the addon must fully reset: cancel timers, stop alert sound, stop screen flash, restore F12 to the initial binding, and return to IDLE state.
