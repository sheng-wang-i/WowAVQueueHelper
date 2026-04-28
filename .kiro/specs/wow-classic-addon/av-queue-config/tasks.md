# 实施计划：设置界面面板

## 概述

为 AVQueueHelper 插件添加设置界面面板功能，包括 SavedVariables 持久化、`/avq` 斜杠命令、日志级别下拉菜单和快捷键绑定输入框。所有修改在现有 `AVQueueHelper.lua` 和 `AVQueueHelper.toc` 两个文件中完成。

## Tasks

- [x] 1. 声明 SavedVariables 并实现设置加载逻辑
  - [x] 1.1 在 AVQueueHelper.toc 中添加 `## SavedVariables: AVQueueHelperDB`
    - 在 .toc 文件的元数据区域添加 SavedVariables 声明
    - _Requirements: 9.1_

  - [x] 1.2 在 AVQueueHelper.lua 中添加 DEFAULTS 表和 LoadSavedSettings 函数
    - 在 CONFIG 表之后添加 `DEFAULTS` 表（logLevel = LOG_LEVEL.INFO, keybind = "F12"）
    - 实现 `LoadSavedSettings()` 函数：若 AVQueueHelperDB 为 nil 则创建空表，遍历 DEFAULTS 填充缺失字段
    - 将 AVQueueHelperDB 中的值加载到 CONFIG.LOG_LEVEL 和 CONFIG.KEYBIND
    - _Requirements: 9.2_

  - [x] 1.3 修改 PLAYER_LOGIN 事件处理器，集成设置加载
    - 在 PLAYER_LOGIN handler 开头调用 `LoadSavedSettings()`（在 faction 检测之前）
    - 使用 `CONFIG.KEYBIND`（来自 SavedVariables）进行初始绑定
    - 确保 targetBtn macrotext 设置和 SetBindingClick 都使用动态 CONFIG.KEYBIND
    - _Requirements: 9.2, 9.8_

  - [-] 1.4 编写属性测试：默认值初始化完整性
    - **Property 1: 默认值初始化完整性**
    - 测试各种 AVQueueHelperDB 初始状态（nil、空表、部分字段、完整字段）经过初始化后结果表包含所有必需字段且已有有效值不被覆盖
    - **Validates: Requirements 9.2**

- [ ] 2. 实现设置面板 Frame 和斜杠命令
  - [ ] 2.1 创建设置面板 Frame
    - 使用 `CreateFrame("Frame", "AVQueueHelperSettingsPanel", UIParent, "BasicFrameTemplateWithInset")` 创建面板
    - 设置面板尺寸（约 300x250）、位置（屏幕居中）、标题文本 "AVQueueHelper Settings"
    - 初始状态隐藏，支持 ESC 关闭（将 "AVQueueHelperSettingsPanel" 加入 `UISpecialFrames`）
    - _Requirements: 9.3_

  - [ ] 2.2 注册 `/avq` 斜杠命令
    - 设置 `SLASH_AVQUEUEHELPER1 = "/avq"`
    - 实现 `SlashCmdList["AVQUEUEHELPER"]` 切换面板显示/隐藏
    - _Requirements: 9.3_

- [ ] 3. 实现日志级别下拉菜单
  - [ ] 3.1 在设置面板中添加日志级别下拉菜单
    - 使用 `UIDropDownMenu_Initialize` + `UIDropDownMenu_CreateInfo` 创建 DEBUG/INFO/WARN/ERROR 四个选项
    - 初始化时根据 CONFIG.LOG_LEVEL 设置当前选中项（`UIDropDownMenu_SetSelectedValue`）
    - 选中时立即更新 `CONFIG.LOG_LEVEL` 和 `AVQueueHelperDB.logLevel`
    - 添加"日志级别"标签文本
    - _Requirements: 9.4, 9.5_

  - [ ]* 3.2 编写属性测试：日志级别更新一致性
    - **Property 2: 日志级别更新一致性**
    - 对任意有效日志级别选择，验证更改后 CONFIG.LOG_LEVEL 和 AVQueueHelperDB.logLevel 同时等于所选值
    - **Validates: Requirements 9.5**

- [ ] 4. 实现快捷键绑定输入框
  - [ ] 4.1 在设置面板中添加快捷键绑定按钮
    - 创建 Button 显示当前绑定按键文本（从 CONFIG.KEYBIND 读取）
    - 点击进入捕获模式（文本变为"按下新按键..."）
    - 添加 `settingsState.capturingKeybind` 状态变量
    - 添加"快捷键绑定"标签文本
    - _Requirements: 9.6_

  - [ ] 4.2 实现快捷键捕获和冲突检测逻辑
    - 在捕获模式下通过 `OnKeyDown` 捕获按键（ESC 退出捕获模式）
    - 调用 `GetBindingAction(key)` 检测冲突
    - 若有冲突：PrintMessage WARN 级别提示冲突动作名称，放弃绑定，退出捕获模式，恢复显示旧按键
    - 若无冲突：`SetBinding(oldKey)` 解除旧绑定，`SetBindingClick(newKey, currentButton)` 绑定新按键，更新 CONFIG.KEYBIND 和 AVQueueHelperDB.keybind，更新按钮显示文本
    - 其中 `currentButton` 为当前阶段对应的安全按钮名称（通过检查 addonState.currentState 确定）
    - _Requirements: 9.7, 9.9_

  - [ ]* 4.3 编写属性测试：无冲突快捷键绑定完整性
    - **Property 3: 无冲突快捷键绑定完整性**
    - 对任意不冲突的按键，验证旧绑定被解除、新按键绑定到当前按钮、CONFIG.KEYBIND 和 AVQueueHelperDB.keybind 均等于新按键
    - **Validates: Requirements 9.7**

  - [ ]* 4.4 编写属性测试：冲突按键绑定拒绝
    - **Property 4: 冲突按键绑定拒绝**
    - 对任意已被绑定的按键，验证产生 WARN 消息、CONFIG.KEYBIND 保持不变、AVQueueHelperDB.keybind 保持不变、不执行 SetBindingClick
    - **Validates: Requirements 9.9**

- [x] 5. 确认现有代码中 KEYBIND 已动态引用
  - [x] 5.1 验证现有代码中所有 SetBindingClick/SetBinding/PrintMessage 调用均使用 CONFIG.KEYBIND
    - ResetState 中 `SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperButton")` ✓
    - GOSSIP_SHOW handler 中 `SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperButton")` ✓
    - BATTLEFIELDS_SHOW handler 中 `SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperJoinButton")` ✓
    - UPDATE_BATTLEFIELD_STATUS handler 中 `SetBindingClick(CONFIG.KEYBIND, "AVQueueHelperEnterButton")` ✓
    - PostClick 中 `SetBinding(CONFIG.KEYBIND, "INTERACTTARGET")` ✓
    - 所有 PrintMessage 中引用 CONFIG.KEYBIND ✓
    - _Requirements: 9.8_

- [ ] 6. 检查点 — 确保所有功能正确集成
  - Ensure all tests pass, ask the user if questions arise.
  - 验证：/avq 切换面板、日志级别下拉菜单工作、快捷键绑定捕获和冲突检测正常、SavedVariables 在 /reload 后保留

## Notes

- 标记 `*` 的任务为可选，可跳过以加快 MVP 进度
- 所有修改仅涉及 AVQueueHelper.lua 和 AVQueueHelper.toc 两个文件
- 属性测试需要提取纯函数并使用 busted 测试框架在游戏外验证
- 每个任务引用具体需求条目以确保可追溯性
