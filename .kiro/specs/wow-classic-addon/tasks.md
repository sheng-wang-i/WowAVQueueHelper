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

- [ ] 8. 添加 SavedVariables 声明与设置加载逻辑
  - [ ] 8.1 在 AVQueueHelper.toc 中添加 SavedVariables 声明
    - 添加 `## SavedVariables: AVQueueHelperDB` 行到 .toc 文件
    - _Requirements: 9.1_

  - [ ] 8.2 实现默认设置与 LoadSavedSettings 函数
    - 在 AVQueueHelper.lua 中定义 DEFAULTS 表（logLevel = LOG_LEVEL.INFO, keybind = "F12"）
    - 实现 LoadSavedSettings()：检查 AVQueueHelperDB 是否为 nil，逐字段合并默认值，将已保存值应用到 CONFIG.LOG_LEVEL 和 CONFIG.KEYBIND
    - 在 PLAYER_LOGIN 事件处理器中调用 LoadSavedSettings()，确保在设置 targetBtn macrotext 和 SetBindingClick 之前执行，使用已保存的 KEYBIND 而非硬编码 F12
    - _Requirements: 9.2, 9.8_

- [ ] 9. 实现设置面板框架与日志级别下拉菜单
  - [ ] 9.1 创建设置面板并注册到 Interface Options
    - 使用 CreateFrame("Frame", "AVQueueHelperSettingsPanel", UIParent) 创建面板
    - 设置 settingsPanel.name = "AVQueueHelper"
    - 调用 InterfaceOptions_AddCategory(settingsPanel) 注册到 ESC → Interface → AddOns
    - 添加面板标题文本
    - _Requirements: 9.3_

  - [ ] 9.2 实现日志级别下拉菜单
    - 使用 CreateFrame("Frame", name, settingsPanel, "UIDropDownMenuTemplate") 创建下拉菜单
    - 实现初始化函数，添加 DEBUG、INFO、WARN、ERROR 四个选项
    - 选项变更回调：立即更新 CONFIG.LOG_LEVEL，同步写入 AVQueueHelperDB.logLevel，更新下拉菜单选中状态
    - 初始化时从 CONFIG.LOG_LEVEL 读取当前值设置默认选中项
    - 添加下拉菜单标签文本
    - _Requirements: 9.4, 9.5_

- [ ] 10. 实现快捷键绑定输入框与冲突检测
  - [ ] 10.1 实现快捷键捕获按钮
    - 创建 Button 框体，显示当前绑定按键文本（从 CONFIG.KEYBIND 读取）
    - 点击按钮后调用 EnableKeyboard(true) 进入按键捕获模式，更新按钮文本提示"按下新按键..."
    - 设置 OnKeyDown 脚本：按 ESCAPE 取消捕获并恢复原文本；其他按键执行绑定变更
    - 绑定变更逻辑：调用 SetBinding(oldKey) 解除旧绑定，更新 CONFIG.KEYBIND，保存到 AVQueueHelperDB.keybind，调用 SetBindingClick(newKey, "AVQueueHelperButton") 绑定新按键，更新按钮显示文本，调用 EnableKeyboard(false) 退出捕获模式
    - 添加快捷键输入框标签文本
    - _Requirements: 9.6, 9.7_

  - [ ] 10.2 实现快捷键冲突检测
    - 在 OnKeyDown 绑定变更前，调用 GetBindingAction(key) 检查按键是否已被游戏内置功能占用
    - 如果返回非空字符串，通过 PrintMessage 输出 WARN 级别警告，告知玩家按键冲突信息
    - 冲突仅警告不阻止绑定（玩家可能有意覆盖）
    - _Requirements: 9.9_

- [ ] 11. 检查点 - 确保设置面板功能完整
  - 确保所有代码无语法错误，如有问题请询问用户。
  - 验证：.toc 文件包含 SavedVariables 声明、PLAYER_LOGIN 中调用 LoadSavedSettings、设置面板已注册到 InterfaceOptions、日志级别下拉菜单包含四个选项、快捷键捕获按钮可正常工作、冲突检测逻辑已实现
  - 确保现有排队流程中所有引用 CONFIG.KEYBIND 的地方（ResetState、PostClick 等）使用动态值而非硬编码 "F12"

## Notes

- All code is Lua targeting the WoW Classic client API (Interface 11503)
- Single-file architecture: AVQueueHelper.lua + AVQueueHelper.toc
- No external build tools, package managers, or test frameworks — addon runs directly in the WoW client
- Protected API constraints require three separate hardware-event keypresses; the addon cannot fully automate the flow in a single press
- Generation counter prevents stale timer callbacks from executing after state resets
- 设置面板通过 WoW 原生 Interface Options 系统注册，无需额外 UI 库
- SavedVariables 由 WoW 客户端在登出时自动序列化到磁盘，PLAYER_LOGIN 时加载并合并默认值
