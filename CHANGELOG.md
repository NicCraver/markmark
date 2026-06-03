# Changelog

本项目的所有重要变更都会记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，
版本号遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

## [1.0.0] - 2026-06-03

首个正式版本。Markdown Reader 是一款 macOS 原生 Markdown 阅读器，采用 SwiftUI + Textual 构建，提供三栏布局：左侧目录树导航 + 中间 Markdown 渲染 + 右侧大纲导航。

### 新增

- **Markdown 渲染引擎**：基于 [Textual](https://github.com/gonzalezreal/textual) 库实现 Markdown 渲染，支持 GFM 扩展（表格、任务列表、删除线等），代码块语法高亮
- **渲染 / 原文模式**：一键切换渲染视图与原始 Markdown 文本，渲染视图支持原生文本选择
- **文件编辑保存**：支持直接编辑 Markdown 文件，Cmd+S 保存，切换文件时自动保留未保存修改（per-file 内容缓存）
- **Per-file Undo 管理**：每个文件独立维护撤销/重做栈，切换文件时完整保留编辑历史
- **新建文件**：右键菜单或快捷键在当前目录下新建 Markdown 文件
- **文件系统监控**：FileSystemWatcher 实时监听文件变更，外部修改自动刷新内容
- **文件树右键菜单**：目录支持新建文档、新建子目录、重命名、移动到、删除；文件支持重命名、移动到、删除
- **未保存修改保护**：关闭未保存文件时弹出确认对话框，可选保存/放弃/取消
- **空目录显示**：文件树递归展示空目录节点
- **自定义双栏布局**：HStack + DragGesture 两列布局，支持拖拽阈值自动隐藏侧边栏、圆角 Detail 区域
- **Buddy 风格界面**：隐藏标题栏 + 自定义窗口控制按钮（TrafficLightButtons），实现 macOS 原生应用体验
- **大纲导航面板**：OutlineView/OutlineService/OutlineItem，自动解析 Markdown 标题结构（ATX + Setext 风格），层级缩进显示，支持 1-6 级标题，点击快速跳转
- **大纲导航滚动同步**：编辑区滚动时自动高亮当前大纲标题
- **主题色彩系统**：23 套预设主题（15 深色 + 8 浅色：Dracula、Catppuccin、Nord、Tokyo Night、Gruvbox、One Dark Pro 等），支持自定义颜色覆盖（surface / ink / accent / success / danger 五色），对比度滑块精细调节
- **外观模式**：支持浅色 / 深色 / 跟随系统三种外观模式
- **多语言本地化**：LocalizationService/L10n 方案，支持简体中文、繁体中文、英文三语，80+ 本地化键值覆盖全部 UI 文字，自动检测系统语言
- **设置系统**：SettingsModel 基于 @Observable + UserDefaults，支持默认显示模式、启动恢复、隐藏文件过滤、外观模式、字体字号、内容边距等配置
- **设置视图**：左侧边栏 + 右侧内容布局，包含主题模式卡片、配色方案网格、自定义颜色条、对比度滑块、字体排版五个区段
- **默认 Markdown 打开程序**：可通过设置将应用注册为 .md/.markdown 文件的默认打开程序
- **最近打开记录**：记录最近打开的文件和目录
- **Git 状态面板**：底部状态栏显示分支、变更计数，可展开变更文件列表及 commit+push 输入区（仅在 Git 仓库中显示）
- **文件树过滤**：支持隐藏文件、非 Markdown 文件过滤
- **键盘导航**：↑↓ 移动文件树，Enter 打开/展开，Cmd+, 设置、Cmd+O 打开、Cmd+\ 切换侧边栏、Cmd+Shift+E/R 切换渲染/原始模式
- **窗口状态恢复**：启动时恢复上次打开的位置
- **应用图标**：全套 macOS AppIcon 尺寸
- **构建与发布**：build-app.sh 支持代码签名与 DMG 打包，package.sh 一键构建打包，GitHub Actions 自动化发布流程

### 变更

- 渲染库从 MarkdownUI 迁移至 Textual（官方继任者）
- 最低部署目标从 macOS 13.0 升级至 macOS 15.0
- 状态管理从 ObservableObject 迁移至 @Observable，启用 Swift 6 严格并发
- 布局方案从 NavigationSplitView 改为自定义 HStack 两列布局
- 窗口样式改用 `.windowStyle(.hiddenTitleBar)`，新增自定义标题栏替代系统 NSToolbar
- ResizeHandle 从 SwiftUI DragGesture 重构为 NSViewRepresentable + NSView 鼠标事件，修复 macOS 拖拽不可靠问题
- RawMarkdownView 替代 SourceMarkdownView，改进原始 Markdown 展示
- 恢复系统原生滚动条，移除自定义主题滚动条

### 移除

- 移除 cmark-gfm 依赖
- 移除 NavigationSplitView 布局方案
- 移除系统 NSToolbar 标题栏
- 移除 Git 模块独立视图（整合至底部状态栏）
