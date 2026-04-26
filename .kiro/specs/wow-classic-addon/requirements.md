# 需求文档

## 简介

本插件为魔兽世界经典版（WoW Classic）设计的战场快速排队便捷插件。玩家按下 F12 键后，插件自动完成从选中 NPC 到加入战场排队的全部流程，省去手动操作的繁琐步骤。目标 NPC 为 "Stormpike Emissary"（雷矛特使），用于奥特兰克山谷战场的排队。

## 术语表

- **Addon**: 魔兽世界客户端加载的 Lua 插件，通过 WoW API 扩展游戏界面和功能
- **Keybinding_Module**: 插件中负责注册和处理按键绑定的模块
- **Target_Module**: 插件中负责选中指定 NPC 的模块
- **Interact_Module**: 插件中负责与目标 NPC 交互（打开对话窗口）的模块
- **Gossip_Module**: 插件中负责处理 NPC 对话选项的模块
- **Queue_Module**: 插件中负责点击加入战场按钮完成排队的模块
- **Stormpike_Emissary**: 联盟阵营的奥特兰克山谷战场排队 NPC，名称为 "Stormpike Emissary"
- **Gossip_Frame**: 与 NPC 对话时弹出的对话选项窗口
- **Battlemaster_Frame**: 战场排队确认窗口，包含 "Join Battle" 按钮
- **Step_Delay**: 每个步骤之间的固定等待时间，设定为 2 秒，用于确保游戏客户端有足够时间响应上一步操作
- **WoW_API**: 魔兽世界客户端提供的 Lua 编程接口，用于操作游戏内对象和界面

## 需求

### 需求 1：按键绑定注册

**用户故事：** 作为玩家，我希望通过按下 F12 键触发战场排队流程，以便快速完成排队操作。

#### 验收标准

1. WHEN Addon 加载完成, THE Keybinding_Module SHALL 注册 F12 键作为触发战场快速排队流程的快捷键
2. WHEN 玩家按下 F12 键, THE Keybinding_Module SHALL 启动战场排队自动化流程
3. WHILE 战场排队流程正在执行中, THE Keybinding_Module SHALL 忽略重复的 F12 按键输入

### 需求 2：自动选中目标 NPC

**用户故事：** 作为玩家，我希望插件自动选中 "Stormpike Emissary" NPC，以便无需手动点击目标。

#### 验收标准

1. WHEN 战场排队流程启动, THE Target_Module SHALL 执行 `/target Stormpike Emissary` 宏命令选中该 NPC
2. WHEN 成功选中 Stormpike_Emissary, THE Target_Module SHALL 等待 Step_Delay（2 秒）后再通知 Interact_Module 继续执行下一步操作
3. IF 未能成功选中 Stormpike_Emissary（NPC 不在附近或不存在）, THEN THE Target_Module SHALL 在聊天窗口显示错误提示信息 "未找到 Stormpike Emissary，请靠近该 NPC 后重试"

### 需求 3：自动打开 NPC 对话窗口

**用户故事：** 作为玩家，我希望插件自动与选中的 NPC 交互打开对话窗口，以便无需手动右键点击 NPC。

#### 验收标准

1. WHEN Target_Module 完成 Step_Delay 等待后, THE Interact_Module SHALL 调用 InteractUnit 函数与目标 NPC 交互
2. WHEN InteractUnit 调用成功且 Gossip_Frame 打开, THE Interact_Module SHALL 等待 Step_Delay（2 秒）后再通知 Gossip_Module 继续执行下一步操作
3. IF InteractUnit 调用失败（目标超出交互距离或目标丢失）, THEN THE Interact_Module SHALL 在聊天窗口显示错误提示信息 "无法与 NPC 交互，请靠近后重试"

### 需求 4：自动选择对话选项

**用户故事：** 作为玩家，我希望插件自动选择 Gossip 对话的第一个选项，以便快速进入战场排队界面。

#### 验收标准

1. WHEN Interact_Module 完成 Step_Delay 等待后且 Gossip_Frame 打开且对话选项可用, THE Gossip_Module SHALL 自动选择第一个 Gossip 对话选项
2. WHEN 第一个对话选项被选择后, THE Gossip_Module SHALL 等待 Step_Delay（2 秒）后再通知 Queue_Module 继续执行下一步操作
3. IF Gossip_Frame 打开但没有可用的对话选项, THEN THE Gossip_Module SHALL 在聊天窗口显示错误提示信息 "对话窗口中没有可用选项"

### 需求 5：自动加入战场排队

**用户故事：** 作为玩家，我希望插件自动点击 "Join Battle" 按钮完成战场排队，以便一键完成整个排队流程。

#### 验收标准

1. WHEN Gossip_Module 完成 Step_Delay 等待后且 Battlemaster_Frame 打开且 "Join Battle" 按钮可用, THE Queue_Module SHALL 自动点击 "Join Battle" 按钮完成战场排队
2. WHEN 战场排队成功完成, THE Queue_Module SHALL 在聊天窗口显示确认信息 "已成功加入战场排队"
3. IF "Join Battle" 按钮不可用或 Battlemaster_Frame 未正确打开, THEN THE Queue_Module SHALL 在聊天窗口显示错误提示信息 "无法加入战场排队，请手动操作"

### 需求 6：流程状态管理

**用户故事：** 作为玩家，我希望插件能正确管理排队流程的状态，以便在异常情况下自动恢复。

#### 验收标准

1. THE Addon SHALL 维护一个流程状态变量，记录当前执行到的步骤（空闲、选中目标、交互中、选择对话、排队中）
2. WHEN 流程中任意步骤失败, THE Addon SHALL 将流程状态重置为空闲状态，允许玩家重新按下 F12 触发流程
3. WHEN 流程成功完成排队, THE Addon SHALL 将流程状态重置为空闲状态
4. IF 流程在 15 秒内未能完成所有步骤（含 3 次 Step_Delay 共计 6 秒）, THEN THE Addon SHALL 超时并将流程状态重置为空闲状态，同时在聊天窗口显示提示信息 "排队流程超时，请重试"

### 需求 7：事件驱动的步骤衔接

**用户故事：** 作为玩家，我希望插件通过游戏事件驱动各步骤的衔接，以便流程稳定可靠。

#### 验收标准

1. THE Addon SHALL 注册 GOSSIP_SHOW 事件用于检测 Gossip_Frame 的打开
2. THE Addon SHALL 注册 BATTLEFIELDS_SHOW 事件（或等效事件）用于检测 Battlemaster_Frame 的打开
3. WHEN 收到 GOSSIP_SHOW 事件且流程状态为交互中, THE Gossip_Module SHALL 等待 Step_Delay（2 秒）后再执行选择第一个对话选项的操作
4. WHEN 收到战场窗口打开事件且流程状态为选择对话, THE Queue_Module SHALL 等待 Step_Delay（2 秒）后再执行点击 "Join Battle" 按钮的操作
5. WHILE 流程状态为空闲, THE Addon SHALL 忽略所有与排队流程相关的游戏事件

### 需求 8：步骤间延迟等待机制

**用户故事：** 作为玩家，我希望插件在每个步骤之间加入固定的等待时间，以便游戏客户端有足够时间响应操作，避免因操作过快导致流程失败。

#### 验收标准

1. THE Addon SHALL 在每个步骤执行完成后等待 Step_Delay（2 秒）再执行下一步操作
2. THE Addon SHALL 使用 C_Timer.After 函数实现 Step_Delay 的延迟等待
3. WHEN 选中 Stormpike_Emissary 成功后, THE Target_Module SHALL 等待 2 秒再触发 InteractUnit 交互操作
4. WHEN InteractUnit 交互成功且 Gossip_Frame 打开后, THE Interact_Module SHALL 等待 2 秒再触发选择对话选项操作
5. WHEN 对话选项选择完成且 Battlemaster_Frame 打开后, THE Gossip_Module SHALL 等待 2 秒再触发点击 "Join Battle" 按钮操作
6. IF 在 Step_Delay 等待期间流程被取消或超时, THEN THE Addon SHALL 取消待执行的延迟回调并将流程状态重置为空闲状态
