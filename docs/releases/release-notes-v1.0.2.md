# Markdown Reader v1.0.2

Bug 修复版本，重点修复双击 .md 文件无法打开应用的问题。

## 🐛 修复

### 📂 双击 .md 文件无法打开应用
- 重写 AppDelegate，改用 `application(_:open:)` 替代 `application(_:openFiles:)`，修复 macOS 15+ 上 SwiftUI WindowGroup 窗口不可见的问题
- 新增 UserDefaults 回退机制解决文件打开时序问题
- 新增 `activateFirstHiddenWindow()` 处理冷启动、热启动和 Dock 点击场景
- Dock 点击时正确激活已有窗口

### 🔧 文件关联优化
- .md 文件关联优先级从 Alternate 提升为 Default
- 新增 UTImportedTypeDeclarations，确保 .md 文件正确关联到应用

### 🎨 应用图标与打包
- 更新全部 AppIcon 尺寸（16–512pt）
- DMG 打包优先使用 create-dmg，支持卷图标
- 移除 DMG 的 ad-hoc 签名，避免 Gatekeeper 误拦截（应用本身仍保留签名）

### 🛡️ 稳定性
- 文件打开通知添加幂等保护，防止重复触发
- 双击文件启动时正确跳过恢复上次位置

## 🖥️ 系统要求

- macOS 15.0 (Sequoia) 或更高版本
- Apple Silicon / Intel 均支持

---

感谢使用 Markdown Reader！如有问题或建议，欢迎在 GitHub Issues 反馈。
