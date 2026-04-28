# 需求文档

## 简介

AVQueueHelper 是一个魔兽世界经典版（WoW Classic）插件，用于简化奥特兰克山谷（AV）战场排队流程。玩家通过连续按下 F12 键三次，依次完成选中 NPC → 与 NPC 交互 → 加入战场排队。插件根据玩家阵营自动选择对应的战场 NPC（联盟为 "Stormpike Emissary"，部落为 "Frostwolf Emissary"）。由于 WoW API 的安全限制，每个受保护操作必须由真实按键触发，因此流程分为三次按键完成。

## 术语表

- **Addon**: 魔兽世界客户端加载的 Lua 插件，通过 WoW API 扩展游戏界面和功能
- **Secure_Action_Button**: WoW 中可在受保护执行路径中运行宏命令的安全按钮框体，通过 `SecureActionButtonTemplate` 创建
- **Protected_API**: 只能在硬件事件（真实按键/点击）的安全执行路径中调用的 WoW API 函数，如 `TargetUnit`、`InteractUnit`、`JoinBattlefield`
- **Keybind_Rebinding**: 在流程的不同阶段将 F12 键绑定到不同的安全按钮，使每次按键执行不同的受保护操作
- **Stormpike_Emissary**: 联盟阵营的奥特兰克山谷战场排队 NPC，名称为 "Stormpike Emissary"
- **Frostwolf_Emissary**: 部落阵营的奥特兰克山谷战场排队 NPC，名称为 "Frostwolf Emissary"
- **Gossip_Frame**: 与 NPC 对话时弹出的对话选项窗口
- **Battlemaster_Frame**: 战场排队确认窗口，包含 "Join Battle" 按钮
- **PVP_Ready_Dialog**: 战场准备就绪时弹出的确认对话框，包含 "Enter Battle" 按钮
- **Step_Delay**: 步骤之间的短暂等待时间（默认 0.2 秒），确保游戏客户端有时间响应
- **Timeout**: 全局超时时间（默认 6 秒），防止流程因异常卡死
- **Generation_Counter**: 递增计数器，用于使旧定时器回调失效，防止状态重置后的过期回调执行
- **STATE**: 流程状态枚举，包含 IDLE、TARGETING、INTERACTING、GOSSIPING、QUEUING、READY 六个状态
- **LOG_LEVEL**: 日志级别枚举，包含 DEBUG、INFO、WARN、ERROR 四个级别
- **Alert_Sound**: 战场准备就绪时的循环提示音（Sound Kit ID 1018），每 3 秒播放一次
- **Screen_Flash**: 战场准备就绪时的全屏红色闪烁效果，提醒玩家进入战场

## 需求

### 需求 1：阵营自适应 NPC 选择

**用户故事：** 作为玩家，我希望插件根据我的阵营自动选择正确的战场 NPC，以便联盟和部落玩家都能使用此插件。

#### 验收标准

1. WHEN 玩家登录游戏（PLAYER_LOGIN 事件触发）, THE Addon SHALL 通过 `UnitFactionGroup("player")` 检测玩家阵营
2. WHEN 玩家为联盟阵营, THE Addon SHALL 将目标 NPC 设置为 "Stormpike Emissary"
3. WHEN 玩家为部落阵营, THE Addon SHALL 将目标 NPC 设置为 "Frostwolf Emissary"
4. IF 无法识别玩家阵营, THEN THE Addon SHALL 在聊天窗口显示警告信息并默认使用联盟 NPC 名称

### 需求 2：按键绑定与安全按钮架构

**用户故事：** 作为玩家，我希望通过按下 F12 键触发战场排队流程，每次按键执行流程中的下一步操作。

#### 验收标准

1. WHEN 玩家登录游戏, THE Addon SHALL 将 F12 键绑定到初始目标按钮（AVQueueHelperButton）
2. THE Addon SHALL 创建以下安全按钮：AVQueueHelperButton（选中 NPC）、AVQueueHelperJoinButton（加入战场排队）、AVQueueHelperEnterButton（进入战场）
3. WHEN 流程推进到不同阶段, THE Addon SHALL 通过 `SetBindingClick` 将 F12 重新绑定到对应的安全按钮
4. WHEN 流程完成、超时或失败, THE Addon SHALL 将 F12 重新绑定回初始目标按钮

### 需求 3：三步按键排队流程

**用户故事：** 作为玩家，我希望通过连续按下 F12 三次完成从选中 NPC 到加入排队的全部流程。

#### 验收标准

1. WHEN 玩家第一次按下 F12 且状态为 IDLE, THE Addon SHALL 执行 `/target <NPC名称>` 宏命令选中战场 NPC
2. WHEN NPC 选中成功, THE Addon SHALL 将 F12 重新绑定到 INTERACTTARGET 操作，将状态设置为 INTERACTING，并在聊天窗口提示玩家再次按下 F12 进行交互
3. IF NPC 未能成功选中（NPC 不在附近）, THEN THE Addon SHALL 在聊天窗口显示警告信息并重置状态为 IDLE
4. WHEN 玩家第二次按下 F12（INTERACTTARGET）, THE Addon SHALL 与目标 NPC 交互打开对话窗口；GOSSIP_SHOW 事件触发后，插件自动在 Step_Delay 后选择第一个对话选项
5. WHEN BATTLEFIELDS_SHOW 事件触发且状态为 GOSSIPING, THE Addon SHALL 将 F12 重新绑定到 AVQueueHelperJoinButton，将状态设置为 QUEUING，并在聊天窗口提示玩家按下 F12 加入排队
6. WHEN 玩家第三次按下 F12, THE Addon SHALL 通过 `/click BattlefieldFrameJoinButton` 点击加入战场按钮，在聊天窗口显示排队完成信息，并重置状态为 IDLE

### 需求 4：战场状态检查与处理

**用户故事：** 作为玩家，我希望插件在我按下 F12 时检查当前战场状态，避免重复排队并在战场结束时自动离开。

#### 验收标准

1. WHEN 玩家按下 F12 且状态为 IDLE, THE Addon SHALL 遍历检查所有战场槽位（1-3）的状态
2. IF 任一战场状态为 "queued"（已在排队中）, THEN THE Addon SHALL 在聊天窗口显示 "已在排队中，请等待" 的提示信息，并不启动排队流程
3. IF 任一战场状态为 "active"（正在战场中）且战场已结束（`GetBattlefieldWinner()` 返回非 nil）, THEN THE Addon SHALL 调用 `LeaveBattlefield()` 自动离开战场并在聊天窗口显示提示
4. IF 任一战场状态为 "active" 且战场未结束, THEN THE Addon SHALL 在聊天窗口显示 "战场仍在进行中" 的提示信息

### 需求 5：战场准备就绪提醒（READY 状态）

**用户故事：** 作为玩家，我希望当战场排队弹出时，插件通过声音和视觉效果提醒我，并允许我按 F12 直接进入战场。

#### 验收标准

1. WHEN UPDATE_BATTLEFIELD_STATUS 事件触发且状态为 IDLE 且任一战场状态为 "confirm", THE Addon SHALL 将状态设置为 READY
2. WHEN 进入 READY 状态, THE Addon SHALL 将 F12 重新绑定到 AVQueueHelperEnterButton
3. WHEN 进入 READY 状态, THE Addon SHALL 立即播放 Alert_Sound（Sound Kit ID 1018），并启动每 3 秒重复播放的定时器
4. WHEN 进入 READY 状态, THE Addon SHALL 启动全屏红色半透明闪烁效果（每 0.5 秒切换显示/隐藏）
5. WHEN 进入 READY 状态, THE Addon SHALL 在聊天窗口显示 "战场准备就绪，按 F12 进入" 的提示信息
6. WHEN 玩家在 READY 状态下按下 F12, THE Addon SHALL 通过 `/click PVPReadyDialogEnterBattleButton` 进入战场，停止声音和闪烁，并重置状态为 IDLE
7. IF 战场确认超时（confirm 状态消失）, THEN THE Addon SHALL 在聊天窗口显示 "战场进入已过期" 的提示，停止声音和闪烁，并重置状态为 IDLE

### 需求 6：流程状态管理与超时机制

**用户故事：** 作为玩家，我希望插件能正确管理排队流程的状态，在异常情况下自动超时重置，防止卡死。

#### 验收标准

1. THE Addon SHALL 维护一个状态机，包含六个状态：IDLE（空闲）、TARGETING（选中目标）、INTERACTING（等待交互）、GOSSIPING（处理对话）、QUEUING（等待排队）、READY（等待进入战场）
2. WHEN 排队流程启动（第一次按下 F12 且开始选中 NPC）, THE Addon SHALL 启动一个 Timeout（默认 6 秒）全局超时定时器
3. IF 流程在 Timeout 时间内未完成, THEN THE Addon SHALL 取消所有定时器、停止声音和闪烁、将 F12 重新绑定到初始按钮、将状态重置为 IDLE，并在聊天窗口显示超时提示
4. WHEN 流程成功完成排队或因任何原因重置, THE Addon SHALL 执行完整的状态清理：取消步骤定时器、取消超时定时器、停止提示音、停止屏幕闪烁、递增 Generation_Counter、重置状态为 IDLE、重新绑定 F12 到初始按钮
5. THE Addon SHALL 使用 Generation_Counter 机制，确保状态重置后旧的定时器回调不会执行过期操作

### 需求 7：事件驱动的步骤衔接

**用户故事：** 作为玩家，我希望插件通过游戏事件驱动各步骤的衔接，使流程稳定可靠。

#### 验收标准

1. THE Addon SHALL 注册以下游戏事件：GOSSIP_SHOW、BATTLEFIELDS_SHOW、UPDATE_BATTLEFIELD_STATUS、PLAYER_LOGIN
2. WHEN 收到 GOSSIP_SHOW 事件且状态为 INTERACTING, THE Addon SHALL 将 F12 重新绑定回初始按钮，然后在 Step_Delay（0.2 秒）后自动选择第一个对话选项并将状态设置为 GOSSIPING
3. WHEN 收到 BATTLEFIELDS_SHOW 事件且状态为 GOSSIPING, THE Addon SHALL 将状态设置为 QUEUING，将 F12 绑定到 AVQueueHelperJoinButton，并提示玩家按 F12 加入排队
4. WHEN 收到 UPDATE_BATTLEFIELD_STATUS 事件且状态为 IDLE, THE Addon SHALL 检查是否有战场状态为 "confirm"，如有则进入 READY 状态
5. WHEN 收到 UPDATE_BATTLEFIELD_STATUS 事件且状态为 READY, THE Addon SHALL 检查所有战场槽位是否仍有 "confirm" 状态；如果所有槽位均不再为 "confirm"，则判定为战场进入已过期，在聊天窗口显示提示并重置状态为 IDLE
6. WHILE 流程状态不匹配事件的预期状态, THE Addon SHALL 忽略该事件（例如 GOSSIP_SHOW 在非 INTERACTING 状态下被忽略）

### 需求 8：日志与消息系统

**用户故事：** 作为玩家，我希望插件在聊天窗口显示清晰的状态信息，帮助我了解当前流程进度和错误原因。

#### 验收标准

1. THE Addon SHALL 支持四个日志级别：DEBUG（1）、INFO（2）、WARN（3）、ERROR（4）
2. THE Addon SHALL 通过 CONFIG.LOG_LEVEL 配置最低显示级别（默认为 INFO），低于该级别的消息不显示
3. ALL 玩家可见的消息 SHALL 使用绿色前缀 `|cFF00FF00[AVQueueHelper]|r` 标识来源
4. THE Addon SHALL 在以下关键节点输出消息：登录绑定完成、NPC 选中成功/失败、提示按键交互、战场窗口打开提示按键加入、排队完成、已在排队中、战场进行中、战场结束自动离开、战场准备就绪、进入战场、流程超时、战场进入过期
5. THE Addon SHALL 永不静默失败——每个状态转换或错误都应产生聊天消息



