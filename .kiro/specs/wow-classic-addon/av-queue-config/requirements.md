# 需求文档 — 设置界面面板

## 简介

本文档描述 AVQueueHelper 插件的设置界面面板需求，允许玩家在游戏内通过 Interface Options 配置插件参数，并通过 SavedVariables 跨会话持久化设置。

## 术语表

- **Settings_Panel**: 通过 WoW 内置 `CreateFrame` 创建的设置界面面板，允许玩家在游戏内配置插件参数
- **SavedVariables**: WoW 客户端在角色登出时自动持久化到磁盘的 Lua 表，用于跨会话保存插件设置数据
- **AVQueueHelperDB**: 插件使用的 SavedVariables 表名，存储玩家的自定义设置（日志级别、快捷键绑定等）

## 需求

### 需求 9：设置界面面板

**用户故事：** 作为玩家，我希望在游戏内通过设置面板配置插件的日志级别和快捷键绑定，以便根据个人需求调整插件行为，且设置在重新登录后仍然保留。

#### 验收标准

1. THE Addon SHALL 在 .toc 文件中声明 `## SavedVariables: AVQueueHelperDB`，使客户端在登出时自动持久化设置数据
2. WHEN 玩家登录游戏（PLAYER_LOGIN 事件触发）, THE Addon SHALL 加载 AVQueueHelperDB 中的已保存设置；IF AVQueueHelperDB 为 nil 或缺少字段, THEN THE Addon SHALL 使用默认值初始化缺失字段（日志级别默认 INFO，快捷键默认 F12）
3. 配置界面可以通过slash command /avq来呼出。
4. THE Settings_Panel SHALL 提供一个日志级别下拉菜单，包含 DEBUG、INFO、WARN、ERROR 四个选项，默认值为 INFO
5. WHEN 玩家在设置面板中更改日志级别, THE Addon SHALL 立即更新 CONFIG.LOG_LEVEL 为所选级别，并将新值保存到 AVQueueHelperDB
6. THE Settings_Panel SHALL 提供一个快捷键绑定输入框，显示当前绑定的按键（默认 F12）
7. WHEN 玩家在设置面板中更改快捷键绑定, THE Addon SHALL 解除旧按键的绑定、将新按键绑定到当前阶段对应的安全按钮、更新 CONFIG.KEYBIND 为新按键值，并将新值保存到 AVQueueHelperDB
8. WHEN 玩家登录游戏且 AVQueueHelperDB 中存在已保存的快捷键设置, THE Addon SHALL 使用已保存的快捷键（而非默认 F12）进行初始绑定
9. IF 玩家设置的快捷键与游戏内置快捷键冲突, THEN THE Addon SHALL 在聊天窗口显示警告信息，告知玩家该按键可能与其他功能冲突, 并且放弃继续绑定。
10. 下拉菜单log level应在窗口出现时就现在目前已经选中的level