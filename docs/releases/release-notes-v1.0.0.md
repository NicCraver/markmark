# Markdown Reader v1.0.0 🎉

首个正式版本发布！Markdown Reader 是一款 macOS 原生 Markdown 阅读器，采用 SwiftUI 构建，提供优雅的阅读体验。

## ✨ 核心功能

### 📖 Markdown 渲染
- 基于 Textual 库的高质量 Markdown 渲染，支持 GitHub Flavored Markdown
- 渲染模式 / 原始模式一键切换（Cmd+Shift+E / Cmd+Shift+R）

### 📂 文件管理
- 文件树浏览器，快速浏览目录中的 Markdown 文件
- 支持隐藏文件和非 Markdown 文件过滤
- 启动时自动恢复上次打开的位置

### 📑 大纲导航
- 文档结构大纲面板，快速跳转到任意标题
- 实时同步当前阅读位置

### 🎨 主题系统
- 23 套预设主题（15 深色 + 8 浅色）
- 自定义颜色覆盖，打造专属配色
- 对比度调节，适应不同环境
- 主题模式：浅色 / 深色 / 跟随系统

### 🌐 多语言
- 支持简体中文、繁体中文、英文
- 自动检测系统语言，也可手动切换

### ⚙️ 设置
- 完整的设置界面：通用 + 外观
- 默认显示模式、字体字号、内容边距等个性化配置

### 🔧 Git 集成
- 底部 Git 状态栏，实时显示分支和变更
- 内置 commit + push 功能，无需离开应用

## 🖥️ 系统要求

- macOS 15.0 (Sequoia) 或更高版本
- Apple Silicon / Intel 均支持

## ⌨️ 快捷键

| 快捷键 | 功能 |
|--------|------|
| Cmd+O | 打开文件或文件夹 |
| Cmd+, | 打开设置 |
| Cmd+\ | 切换侧边栏 |
| Cmd+Shift+E | 切换到渲染模式 |
| Cmd+Shift+R | 切换到原始模式 |

## ⚠️ 已知限制

- 首个版本，未经 Apple 公证。打开时如遇 Gatekeeper 警告，请右键点击 → 打开
- 仅支持 macOS 15.0+，不支持旧版系统

---

感谢使用 Markdown Reader！如有问题或建议，欢迎在 GitHub Issues 反馈。
