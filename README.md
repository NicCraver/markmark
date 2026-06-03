# Markdown Reader

一款 macOS 原生 Markdown 阅读器，采用 SwiftUI + Textual 构建，提供三栏布局：左侧目录树导航 + 中间 Markdown 渲染 + 右侧大纲导航。灵感源自 [Buddy macOS](https://buddy.dev) 的设计风格。

![macOS 15.0+](https://img.shields.io/badge/macOS-15.0+-blue)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

## ✨ 功能特性

### 📖 Markdown 渲染与编辑
- 基于 [Textual](https://github.com/gonzalezreal/textual) 渲染引擎，支持 GFM 扩展（表格、任务列表、删除线等）
- GitHub 风格渲染，代码块语法高亮
- 渲染视图支持原生文本选择
- 渲染 / 原文模式一键切换
- **直接编辑**：原文模式下可直接编辑 Markdown，Cmd+S 保存
- 切换文件时自动保留未保存修改（per-file 内容缓存）
- 每个 file 独立 Undo/Redo 栈
- 外部文件变更自动检测刷新（FileSystemWatcher）

### 🌲 目录树导航
- 递归展示文件目录结构（含空目录）
- 键盘导航（↑↓ 移动，Enter 打开/展开）
- 支持隐藏文件 / 非 Markdown 文件过滤
- 可拖拽调整宽度，拖过阈值自动隐藏
- 单文件模式支持（从 Finder 直接打开单个 .md 文件）
- **右键菜单**：新建文件/子目录、重命名、移动到、删除
- 未保存修改保护：关闭未保存文件时弹出确认对话框

### 📑 大纲导航
- 自动解析 Markdown 标题结构（ATX + Setext 风格）
- 层级缩进显示，支持 1-6 级标题
- 可拖拽调整面板宽度
- 代码块内的标题自动跳过

### 🎨 主题系统
- **23 套预设主题**：15 深色 + 8 浅色（Dracula、Catppuccin、Nord、Tokyo Night、Gruvbox、One Dark Pro 等）
- 自定义颜色覆盖：可覆盖 surface / ink / accent / success / danger 五色
- 对比度滑块精细调节（0-100）
- 支持浅色 / 深色 / 跟随系统三种外观模式
- 语义化色彩 Token 系统（12+ 派生色值）

### 🌍 多语言本地化
- 支持简体中文、繁体中文、英文三语
- 自动检测系统语言
- 80+ 本地化键值，覆盖全部 UI 文字

### ⚙️ 设置系统
- 通用设置：语言、默认显示模式、启动恢复、文件过滤
- 外观设置：主题模式、配色方案、自定义颜色、对比度、字号、内容边距
- 默认 Markdown 打开程序设置
- 基于 @Observable + UserDefaults 持久化

### 🔀 Git 集成
- 底部状态栏显示当前分支、变更计数
- 可展开查看 staged / modified / untracked 文件列表
- 支持 Commit & Push 一键操作
- 仅在 Git 仓库中显示

### 🪟 窗口体验
- Buddy 风格隐藏标题栏 + 自定义交通灯按钮
- 窗口状态恢复（重新打开上次浏览位置）
- 全屏模式支持
- 自定义拖拽调整手柄（NSViewRepresentable，可靠拖拽体验）

## ⌨️ 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd+O` | 打开目录 / 文件 |
| `Cmd+,` | 打开设置 |
| `Cmd+\` | 切换侧边栏显隐 |
| `Cmd+Shift+E` | 切换到渲染模式 |
| `Cmd+Shift+R` | 切换到原文模式 |

## 🛠 技术栈

| 组件 | 技术 |
|------|------|
| UI 框架 | SwiftUI |
| Markdown 渲染 | [Textual](https://github.com/gonzalezreal/textual) v0.3.1+ |
| 语言 | Swift 6.0（严格并发） |
| 最低部署目标 | macOS 15.0 (Sequoia) |
| 状态管理 | @Observable |
| 构建系统 | Swift Package Manager |
| CI/CD | GitHub Actions |

## 📦 安装

### 下载安装

前往 [Releases](https://github.com/davidhoo/MarkdownReader/releases) 下载最新版 DMG，拖入应用程序文件夹即可。

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/davidhoo/MarkdownReader.git
cd MarkdownReader

# 构建运行
swift build -c release

# 或构建 .app 包
./build-app.sh --release
```

## 🏗 项目结构

```
Sources/MarkdownReader/
├── App/                    # 应用入口
│   └── MarkdownReaderApp.swift
├── Models/                 # 数据模型
│   ├── DisplayMode.swift
│   ├── Document.swift
│   ├── FileError.swift
│   ├── FileNode.swift
│   ├── OutlineItem.swift
│   ├── SettingsModel.swift
│   └── ThemeDefinition.swift
├── Services/               # 服务层
│   ├── FileService.swift
│   ├── GitService.swift
│   ├── LanguageService.swift
│   ├── LocalizationService.swift
│   ├── OutlineService.swift
│   └── ThemeColors.swift
├── ViewModels/             # 视图模型
│   ├── AppViewModel.swift
│   ├── DocumentViewModel.swift
│   ├── FileTreeViewModel.swift
│   └── GitViewModel.swift
└── Views/                  # 视图层
    ├── ContentView.swift
    ├── DetailView.swift
    ├── ErrorView.swift
    ├── FileRowView.swift
    ├── OutlineResizeHandle.swift
    ├── OutlineView.swift
    ├── ProjectStatusView.swift
    ├── RawMarkdownView.swift
    ├── RenderedMarkdownView.swift
    ├── ResizeHandle.swift
    ├── SettingsView.swift
    ├── SidebarView.swift
    ├── TrafficLightButtons.swift
    └── WelcomeView.swift
```

## 📄 文档

- [需求文档](docs/requirements.md) — 产品需求与功能规格
- [设计文档](docs/design.md) — UI 设计与交互规范
- [架构文档](docs/architecture.md) — 技术架构与设计决策
- [开发计划](docs/plan.md) — 里程碑与迭代规划

## 📜 许可证

MIT License
