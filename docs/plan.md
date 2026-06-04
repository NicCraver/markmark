# Markdown Reader — 开发计划

## 1. 里程碑概览

| 阶段 | 内容 | 预计工时 | 状态 |
|------|------|----------|------|
| M1 | 项目初始化 + 基础框架 + 打开目录 | 1-1.5天 | ✅ 已完成 |
| M2 | Sidebar 目录树 | 1-2天 | ✅ 已完成 |
| M3 | Markdown 渲染显示 | 1天 | ✅ 已完成 |
| M4 | 原文视图 + 渲染/原文切换 | 0.5-1天 | ✅ 已完成 |
| M5 | 集成测试 + 优化 | 1天 | ✅ 已完成 |
| M6 | 主题系统 + 设置视图 | 2天 | ✅ 已完成 |
| M7 | 大纲导航面板 | 1天 | ✅ 已完成 |
| M8 | 多语言本地化 + Git 集成 | 1.5天 | ✅ 已完成 |
| M9 | 构建/发布流程 + 默认打开程序 | 1天 | ✅ 已完成 |

**实际总工时：约 10-12 天**

## 2. 详细计划

### M1：项目初始化 + 基础框架 + 打开目录 ✅

**目标：** 创建项目，集成依赖，搭建基础布局，实现打开目录功能

- [x] 创建 SwiftUI macOS 项目（MarkdownReader）
- [x] 配置 SPM 依赖：Textual (gonzalezreal/textual v0.3.1+)
- [x] 设置最低部署目标：macOS 15.0
- [x] 配置窗口样式：`.windowStyle(.hiddenTitleBar)` + `.defaultSize(width: 900, height: 600)`
- [x] 创建自定义 HStack 两列布局骨架（含 ResizeHandle 分隔线）
- [x] 创建基础 Model：FileNode, Document, DisplayMode
- [x] 创建基础 ViewModel：AppViewModel, FileTreeViewModel, DocumentViewModel（使用 @Observable）
- [x] 创建 FileService
- [x] 实现打开目录功能（Cmd+O，NSOpenPanel）
- [x] 创建 WelcomeView 空状态视图
- [x] 窗口标题显示逻辑

**交付物：** ✅ 可运行的应用，能打开目录，显示 Welcome 空状态，两列布局可见

### M2：Sidebar 目录树 ✅

**目标：** 实现完整的目录树导航功能

- [x] FileService 实现目录扫描（递归遍历，.md 文件正常显示，非 .md 文件灰显）
- [x] FileNode 构建树形结构（添加 isMarkdown, isChildrenLoaded 属性）
- [x] SidebarView 使用递归 DisclosureGroup 渲染目录树
- [x] 点击文件切换选中状态
- [x] 点击目录展开/折叠
- [x] Sidebar 显隐切换（TitleBar 按钮 + Cmd+\）
- [x] ResizeHandle：NSViewRepresentable + NSView 鼠标事件（替代不可靠的 SwiftUI DragGesture）
- [x] Sidebar 拖拽低于 140px 阈值自动隐藏，恢复默认 240pt
- [x] 当前选中行高亮
- [x] SF Symbols 图标（folder.fill/doc.text/doc）
- [x] 非 .md 文件灰显样式
- [x] 键盘导航（↑↓ 移动选中，Enter 打开/展开）
- [x] 空目录状态提示

**交付物：** ✅ 可浏览目录树，键盘/鼠标均可导航

### M3：Markdown 渲染显示 ✅

**目标：** 实现右侧 Markdown 渲染显示

- [x] DocumentViewModel 读取文件内容（含错误处理）
- [x] 选中文件时自动加载内容
- [x] RenderedMarkdownView 使用 Textual `StructuredText` 渲染
- [x] 应用 `.textual.structuredTextStyle(.gitHub)` 预设风格
- [x] 支持 GFM 扩展（表格、任务列表等）
- [x] 适配深色/浅色模式
- [x] 链接点击在默认浏览器打开
- [x] 使用 `.id(fileURL)` 确保视图正确重建
- [x] 滚动视图支持
- [x] ErrorView 错误提示视图

**交付物：** ✅ 点击文件可看到渲染后的 Markdown 内容，链接可点击

### M4：原文视图 + 渲染/原文切换 ✅

**目标：** 实现原文视图和自定义 TitleBar 切换

- [x] RawMarkdownView 等宽字体（SF Mono）显示原文
- [x] Word Wrap 默认启用
- [x] 文本选择和复制支持
- [x] 自定义 TitleBar（内嵌于 DetailView，50px）：Segmented Picker（渲染/原文）
- [x] TitleBar 内 Sidebar 显隐按钮
- [x] TitleBar 内大纲面板切换按钮
- [x] 切换渲染/原文视图
- [x] 快捷键：Cmd+Shift+E / Cmd+Shift+R 切换

**交付物：** ✅ 完整的核心功能可用，可在渲染和原文间切换

### M5：集成测试 + 优化 ✅

**目标：** 确保应用稳定可用

- [x] 深色/浅色模式切换测试
- [x] 边界情况处理（空目录、权限问题、编码异常、非 .md 文件点击）
- [x] 窗口尺寸约束验证
- [x] 快捷键功能验证
- [x] 键盘导航全流程验证
- [x] 修复发现的问题

**交付物：** ✅ 稳定可用的应用

### M6：主题系统 + 设置视图 ✅

**目标：** 实现完整的主题系统和设置界面

- [x] ThemeDefinition 模型：5 核心色 + 对比度
- [x] PresetThemes 枚举：23 套预设主题（15 深色 + 8 浅色）
- [x] ThemeCustomOverrides 自定义颜色覆盖
- [x] ThemeColors 服务：12+ 语义 token 派生
- [x] SwiftUI Environment 注入主题色彩
- [x] AppearanceMode 三种模式（light/dark/system）
- [x] SettingsView 两栏布局（General + Appearance）
- [x] 通用设置：语言、显示模式、启动恢复、文件过滤
- [x] 外观设置：主题模式卡片、配色方案网格、自定义颜色条（NSColorPanel + hex 编辑）、对比度滑块、字体排版
- [x] SettingsModel 单例：@Observable + UserDefaults 持久化
- [x] 自定义 TrafficLightButtons（替代系统红绿灯）

**交付物：** ✅ 完整的主题系统和设置界面

### M7：大纲导航面板 ✅

**目标：** 实现右侧大纲导航面板

- [x] OutlineItem 模型：level (1-6), title, lineNumber
- [x] OutlineService 标题解析（ATX + Setext 风格，跳过代码块）
- [x] OutlineView 层级缩进显示（14pt/级，字号按层级递减）
- [x] OutlineResizeHandle 可拖拽调整宽度（150-350pt，默认 200pt）
- [x] 大纲面板显隐切换
- [x] Hover 行高亮效果

**交付物：** ✅ 可用的大纲导航面板

### M8：多语言本地化 + Git 集成 ✅

**目标：** 实现多语言支持和 Git 状态显示

- [x] LocalizationService 自定义字典方案（80+ 键值）
- [x] 三语言完整翻译（zh-CN, zh-TW, en）
- [x] LanguageService 系统语言检测
- [x] SwiftUI Environment 语言注入
- [x] GitService 封装 /usr/bin/git（status/add/commit/push）
- [x] GitViewModel 管理 Git 状态
- [x] ProjectStatusView 底部状态栏（分支、变更计数、文件列表、commit+push）
- [x] 设置中语言偏好选项

**交付物：** ✅ 完整的多语言支持和 Git 集成

### M9：构建/发布流程 + 默认打开程序 ✅

**目标：** 完善构建和发布流程

- [x] build-app.sh 构建脚本（支持代码签名和 DMG 打包）
- [x] GitHub Actions release.yml 自动化发布流程
- [x] 默认 Markdown 打开程序设置（NSWorkspace 注册）
- [x] 全套 AppIcon 资源
- [x] docs/releases/release-notes-v1.0.0.md 发布说明

**交付物：** ✅ 完整的构建发布流程

## 3. 后续迭代

### P2（下一版本）

- [ ] 大纲面板 scroll-to-line 跳转功能
- [ ] 拖拽打开（将目录或文件拖拽到应用窗口）
- [ ] 原文视图语法高亮
- [ ] 文件内搜索（Cmd+F）
- [ ] 原文视图行号显示
- [ ] 切换文件时记忆渲染/原文状态

### P3（远期）

- [ ] 目录树文件名搜索
- [ ] 全文搜索
- [ ] 导出为 PDF
- [ ] 多窗口支持

## 4. 风险与注意事项

| 风险 | 影响 | 应对 | 状态 |
|------|------|------|------|
| Textual v0.x API 不稳定 | 升级时需适配代码 | 锁定小版本号 `.upToNextMinor(from: "0.3.1")`，关注 release notes | 持续关注 |
| Textual 大文件性能 | 渲染卡顿 | 实测 500KB+ 文件性能，必要时大文件降级为原文视图 | 待验证 |
| macOS 15.0+ 限制 | 缩小用户范围 | 目标用户为开发者，macOS 15 采用率可接受 | 已接受 |
| Swift 6 严格并发 | 编译错误 | ViewModel 标注 `@MainActor`，确保 Sendable 合规 | 已解决 |
| 自定义布局窗口 resize 状态同步 | 宽度偏移累积 | 基于 sidebarWidth 绝对值计算而非累加 translation | 已解决 |
| 全屏模式 TitleBar 适配 | 红绿灯行为异常 | 处理全屏模式下红绿灯区域宽度变化（76px → 32px） | 已解决 |
| Git Process 依赖 | 无 git 时功能不可用 | 仅影响 Git 面板，不影响核心功能 | 已接受 |
