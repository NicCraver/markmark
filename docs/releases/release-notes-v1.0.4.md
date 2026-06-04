# Markdown Reader v1.0.4

改进滚动条样式、新增复制路径功能、优化文件打开体验。

## ✨ 新增

### 📋 复制路径
- 标题栏新增一键复制文件路径按钮
- 文件树右键菜单新增「复制路径」选项（目录和文件均可）

### 📜 滚动条
- 自定义 6px 圆角细滚动条（ThinOverlayScroller），覆盖文件树等非文本区域
- OverlayScrollerHelper 三级搜索策略：superview 链 → 兄弟视图 → 祖先区域

### 🔒 稳定性
- OpenPanelHelper 重入保护，防止重复弹窗
- Package.resolved 纳入版本控制，确保构建可复现

## 🔧 变更

- 直接调用 OpenPanelHelper 替代通知方式，避免 WindowGroup 多实例重复弹窗
- 文件加载幂等保护，已加载同一文件时跳过重复加载
- 热启动移除 300ms 延迟，文件打开响应更快
- 移除冗余 UserDefaults.synchronize() 调用
- 精简 ContentView 中 4 处冗余 loadFile 调用
- 应用图标更新

## 🖥️ 系统要求

- macOS 15.0 (Sequoia) 或更高版本
- Apple Silicon / Intel 均支持

---

感谢使用 Markdown Reader！如有问题或建议，欢迎在 GitHub Issues 反馈。
