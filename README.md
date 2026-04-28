# AVQueueHelper

A World of Warcraft Classic addon that streamlines Alterac Valley battleground queuing into a simple repeating keypress flow.

## Usage

### Queue Flow

1. Stand near the Alterac Valley battlemaster NPC
2. Press your keybind (default `F12`) — targets the NPC
3. Press again — interacts with the NPC (gossip option auto-selected)
4. Press again — joins the battleground queue

When the queue pops, the addon alerts you with sound and screen flash. Press the same keybind once more to enter the battleground.

If you're already inside a finished battleground, press the keybind to auto-leave. Then you can repeat the loop to queue again.

### Settings Panel

Type `/avq` in chat to open the settings panel. From there you can:

- Change the log level (DEBUG / INFO / WARN / ERROR)
- Change the keybind to any key you prefer

Settings are saved automatically and persist across sessions.
