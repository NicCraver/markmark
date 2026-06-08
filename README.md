# Markdown Reader

> 不是又一个全能编辑器，只是一个安静的阅读器。
![screenshot](screenshot.png)

![macOS 26+](https://img.shields.io/badge/macOS-26+-blue)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## 为什么选它？

市面上 Markdown 工具越来越多，功能一个比一个全——实时协作、云端同步、插件生态……但很多时候，你只是想**快速打开一个 .md 文件，安安静静地读完它**。

Markdown Reader 就是为这个场景而生：

- **没有心理负担** — 不注册、不登录、没有复杂配置，打开即用
- **秒开秒读** — 原生 macOS 应用，启动快、切换快、阅读流畅
- **专注阅读** — 三栏布局，目录树 + 渲染视图 + 大纲导航，一眼看清文档结构
- **极小极轻** — DMG 安装包不到 10MB，不占空间

当你不需要写作、不需要协作、不需要花哨功能，只想**快速查看 Markdown 文档**时，它就是最合适的选择。

---

## 功能

| 功能 | 说明 |
|------|------|
| WKWebView 渲染引擎 | cmark-gfm + WKWebView 渲染，完整 GFM 扩展语法 |
| Mermaid 图表 | 流程图、时序图、甘特图等 Mermaid 图表本地渲染 |
| PlantUML 图表 | 支持 PlantUML 语法，自动渲染为 SVG 图表（需要网络） |
| 数学公式 | KaTeX 渲染 LaTeX 行内和块级公式 |
| Prism.js 代码高亮 | 30+ 语言语法高亮，Prism.js 引擎 |
| Quick Look 预览 | Finder 中选中 .md 文件按空格即可预览渲染效果，无需打开应用 |
| 实时编辑 | 原文模式直接编辑，Cmd+S 保存，切换文件自动保留未保存内容 |
| 目录树 | 递归浏览文件夹，键盘导航，右键新建/重命名/删除 |
| 大纲导航 | 自动提取标题层级，点击跳转，阅读长文档更高效 |
| 33 套主题 | 20 深色 + 13 浅色，含 Markdown Preview Enhanced 风格主题，支持自定义配色和对比度调节 |
| 多语言 | 简体中文、繁体中文、英文，自动跟随系统 |
| 命令行工具 | `mdr` 命令从终端直接打开 Markdown 文件 |
| 窗口恢复 | 记住上次浏览位置，重新打开自动还原 |

---

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| `Cmd+O` | 打开目录 / 文件 |
| `Cmd+N` | 新建文件 |
| `Cmd+S` | 保存文件 |
| `Cmd+,` | 打开设置 |
| `Cmd+\` | 切换侧边栏 |
| `Cmd+Shift+E` | 渲染模式 |
| `Cmd+Shift+R` | 原文模式 |
| `Cmd+F` | 查找 |
| `Cmd+G` | 查找下一个 |
| `Cmd+Shift+G` | 查找上一个 |
| `Cmd+Option+F` | 查找与替换 |

---

## 安装

### 下载安装

前往 [Releases](https://github.com/davidhoo/MarkdownReader/releases) 下载最新版 DMG，拖入应用程序文件夹即可。

### 系统要求

macOS 26 (Tahoe) 或更高版本。

---

## 官方网站

[https://davidhoo.github.io/MarkdownReader/](https://davidhoo.github.io/MarkdownReader/)

---

MIT License
