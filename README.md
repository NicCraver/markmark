# MarkMark

> 一个安静的 macOS Markdown 阅读器 —— 现在还能边读边批注，一键把意见交给 AI。

![macOS 15+](https://img.shields.io/badge/macOS-15+-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## 这是什么

MarkMark 是一个原生 macOS Markdown 阅读器。三栏布局：左侧目录树 + 中间渲染视图 + 右侧大纲导航，打开即用、秒开秒读。

它在一个经典阅读器的基础上，加入了一套**审阅工作流**：当你在读一份 Markdown（尤其是 AI 生成的内容）时，可以直接在渲染页面里选中文字做标注 —— 删除、替换、评论、高亮 —— 然后**一键复制带标注的文档交给 AI**，让它据此修订。读 → 批 → 交给 AI 改，闭环。

<img width="1012" height="712" alt="image" src="https://github.com/user-attachments/assets/7d843581-a803-4d43-ab64-9978a40735a9" />
<img width="1012" height="712" alt="image" src="https://github.com/user-attachments/assets/88bb69db-bfbe-40f5-a34a-7fb27b43f4c5" />
<img width="1041" height="712" alt="image" src="https://github.com/user-attachments/assets/1b7a3279-ed89-4a57-875c-04bdfb58c552" />
<img width="1012" height="712" alt="image" src="https://github.com/user-attachments/assets/100ac9a2-b9ad-4b20-84eb-ead28e4efac2" />
<img width="1012" height="712" alt="image" src="https://github.com/user-attachments/assets/451eff98-37ed-47c3-b3ef-0b4e20727bfc" />

---

## ✨ 核心特性：CriticMarkup 审阅

- **边读边标注** — 在渲染视图里选中任意文字，浮动工具条提供四种操作：
  - **删除** `{--...--}`、**高亮** `{==...==}`、**评论** `{>>...<<}`、**替换** `{~~旧~>新~~}`
- **所见即所得的批注样式** — 新增绿色、删除红色删除线、评论 💬 气泡、高亮强调色，阅读时一目了然
- **一键复制给 AI** — 标题栏 ✨ 按钮（或 `⌘⇧C`）复制「引导提示词 + 带 CriticMarkup 标注的全文」，粘贴给任意大模型即可让它理解并修订
- **一键清除标注** — 橡皮擦按钮把文档恢复为原文
- 标注采用标准 [CriticMarkup](http://criticmarkup.com) 语法，纯文本、可移植、不锁定

> 典型用法：让 AI 写了一篇 Markdown → 用 MarkMark 打开 → 选中有问题的句子标注「这里要改成…」「这段删掉」「补个数据来源」→ ✨ 复制 → 丢回对话框让 AI 重写。

---

## 阅读器功能

| 功能 | 说明 |
|------|------|
| WKWebView 渲染引擎 | cmark-gfm + WKWebView 渲染，完整 GFM 扩展语法 |
| Mermaid 图表 | 流程图、时序图、甘特图等本地渲染 |
| PlantUML 图表 | 支持 PlantUML 语法，自动渲染为 SVG（需要网络） |
| 数学公式 | KaTeX 渲染 LaTeX 行内和块级公式 |
| 代码高亮 | Prism.js，30+ 语言语法高亮，代码块一键复制 |
| Quick Look 预览 | Finder 中选中 .md 按空格即可预览渲染效果 |
| 多窗口 | 双击不同文件各开一个独立窗口 |
| 目录树 | 递归浏览文件夹，键盘导航，右键新建/重命名/删除 |
| 大纲导航 | 自动提取标题层级，点击跳转 |
| PDF 导出 | 渲染结果导出为 PDF |
| 33 套主题 | 20 深色 + 13 浅色，支持自定义配色与对比度 |
| 多语言 | 简体中文、繁体中文、英文，自动跟随系统 |

---

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `⌘O` | 打开目录 / 文件 |
| `⌘N` | 新建文件 |
| `⌘S` | 保存文件 |
| `⌘⇧C` | 复制带标注文档给 AI |
| `⌘⌥E` | 导出 PDF |
| `⌘,` | 打开设置 |
| `⌘\` | 切换侧边栏 |
| `⌘⇧E` / `⌘⇧R` | 渲染模式 / 原文模式 |
| `⌘F` / `⌘G` / `⌘⇧G` | 查找 / 下一个 / 上一个 |
| `⌘⌥F` | 查找与替换 |

---

## 构建与运行

```bash
# 调试构建
swift build

# 运行测试（CriticMarkup 核心逻辑）
swift test

# 构建 .app 包（含 ad-hoc 签名）— Apple Silicon
./build-app.sh --release --sign

# 打包 DMG
./package.sh
```

### 系统要求

macOS 15.0 或更高版本（Apple Silicon）。

---

## 致谢 · Inspired by

MarkMark fork 自并致敬 [**davidhoo/MarkdownReader**](https://github.com/davidhoo/MarkdownReader) —— 一个出色的、专注阅读的原生 macOS Markdown 阅读器。

在它的基础上，MarkMark 主要做了三件事：

1. **把最低系统要求从 macOS 26 下调到 macOS 15** —— 将渲染层从仅 macOS 26 可用的 SwiftUI `WebView`/`WebPage` 迁移回经典 `WKWebView`。
2. **加入 CriticMarkup 审阅与「复制给 AI」工作流** —— 让阅读器变成一个轻量的 AI 内容评审工具。
3. **移除编辑功能，精简为纯「阅读 + 批注」** —— 定位更聚焦：不做编辑器，只做安静的阅读与审阅。

感谢原作者的工作。原项目同为 MIT 许可。

---

MIT License
