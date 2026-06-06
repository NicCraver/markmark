# 大文件渲染性能分析报告

> 两轮分析（opencode + claude）一致结论 + 用户关键洞察，待用户确认后实施

## 一、问题定义

**典型场景**：打开 85KB / 1567 行的 Markdown 文件（如 buddy/REQUIREMENTS.md）

**现象**：
1. **首次渲染极慢** — 切换到渲染模式后，内容显示需要数秒
2. **滚动严重卡顿** — 渲染模式下拖动滚动条不丝滑，有明显掉帧和延迟

**对比**：Raw 模式（NSTextView）不存在此问题，因为 AppKit 原生文本布局有虚拟化。

---

## 二、根因分析

### 根本原因：Textual StructuredText 全量渲染 + SwiftUI ScrollView 无虚拟化

渲染管线的每一步都**对整个文档全量操作**：

```
FileService.readFile() → 全文本 String (85KB)
    ↓
MarkdownContentPreprocessor.preprocess() → 5轮正则替换（全文本）
    ↓
SupSubMarkupParser.attributedString(for:) → Foundation 解析全文本 Markdown
    ↓
restoreLinkedImageLinks() → 遍历全部 AttributedString runs
    ↓
applySupSubFormatting() → 逐字符遍历全部内容
    ↓
Textual StructuredText → 生成整个文档的 SwiftUI View 树
    ↓
BlockVStackLayout → 遍历全部 subviews 计算尺寸 + 放置
    ↓
SwiftUI ScrollView + VStack → 无虚拟化，全部 block 同时存在
    ↓
滚动 → 每帧合成整个视图树（无视图回收）
```

### 为什么 Raw 模式不卡

| 特性 | Raw 模式 (NSTextView) | 渲染模式 (Textual) |
|------|----------------------|-------------------|
| 布局虚拟化 | ✅ 只布局可见区域 glyph | ❌ 全部 block 同时布局 |
| 滚动机制 | NSScrollView 原生 | SwiftUI ScrollView（无回收） |
| 语法高亮 | 正则全扫描但增量布局 | 异步分词 × N个代码块 |
| 内存占用 | NSTextView 按需分配 | 全部 View 树常驻 |

### 瓶颈量化（85KB 文件估算）

| 阶段 | 估计耗时 | 说明 |
|------|---------|------|
| 预处理（5轮正则） | ~5ms | 中等 |
| Foundation Markdown 解析 | ~200-500ms | **高** |
| Textual View 树生成 | ~100-300ms | **高**（200-400个 Block View） |
| BlockVStackLayout 布局 | ~50-100ms | **高**（遍历全部 subviews） |
| 代码块异步分词 | ~200-500ms | **高**（每个代码块独立 tokenize task） |
| **首次渲染总计** | **~550-1400ms** | |
| **滚动每帧** | **>16ms（卡顿）** | 合成整个文档视图树 |

### 次要瓶颈

1. **highlighterTheme 每次重新计算** — 20+ 次 NSColor 转换和混合运算，无缓存
2. **SVG 图片渲染** — 每张 SVG 创建 WKWebView + 2-3秒 Task.sleep
3. **RawMarkdownView 始终存活** — ZStack opacity(0/1) 模式，渲染模式下 NSTextView 仍占内存
4. **OutlineService 全量分割** — `components(separatedBy:)` 分割全文为数组
5. **文件变更检测** — 每次事件读全文并做 String 比较

---

## 三、方案评估

### 方案 A：WKWebView 渲染

**思路**：用 WebView 渲染 Markdown HTML，利用浏览器的虚拟滚动。

**优点**：
- 浏览器滚动性能工业级，天然支持大文档
- CSS 渲染丰富（GitHub 风格、代码高亮等生态成熟）
- 图片懒加载原生支持
- markdown-it / marked.js 等解析器极快

**缺点**：
- 丧失 SwiftUI 原生渲染视觉一致性
- **文本选择体验降级** — WKWebView 的文本选择不如原生丝滑，对阅读器核心交互有影响
- 需要 JS Bridge（大纲点击、文本选择、滚动同步），调试困难
- WebView 初始化有 ~100ms 开销，内存占用比 NSTextView 高
- 主题系统需重新实现（CSS 变量映射不可能 100% 还原 ThemeColors 所有语义 token）
- 现有 EquatableRenderedMarkdownView / ScrollHelperView / ScrollViewCapturer 全部无法复用

**工作量**：4-6 天

### 方案 B：NSTextView + NSAttributedString 富文本渲染

**思路**：大文件时用 NSTextView 渲染 NSAttributedString，复用 AppKit 虚拟化。

**优点**：
- 与现有 RawMarkdownView 架构一致
- AppKit 原生滚动虚拟化
- 可渐进实现

**缺点**：
- Foundation 的 `AttributedString(markdown:)` 生成的基础富文本**缺少**：表格布局、代码块语法高亮、引用块样式、任务列表勾选框
- 需要自行实现或引入 cmark/Down 库做 Markdown → NSAttributedString 转换
- 表格和复杂布局在 NSTextView 中极难实现好
- 文本选择、链接点击等交互需重新处理
- **对于一个「安静的阅读器」，视觉质量是核心价值，NSTextView 做不出好效果**

**工作量**：5-7 天，且**复杂布局质量难保证**

### 方案 C：分块渲染 + LazyVStack

**思路**：将文档按标题/段落分块，每块独立 StructuredText，外层 LazyVStack。

**优点**：
- 保留 Textual 渲染质量
- LazyVStack 提供虚拟化
- 改动最小

**缺点**：
- **关键问题**：按标题分块会截断标题间的内容，跨块内联元素断裂
- AttributedString 的 PresentationIntent 分割不简单
- LazyVStack 在 macOS 有已知跳跃/闪烁 bug
- 分块边界间距管理复杂

**工作量**：2-3 天，但**风险高**，可能做不出好效果

### 方案 D：优化现有架构（不做引擎替换）

| 优化项 | 预期收益 | 工作量 |
|--------|---------|--------|
| 缓存 SupSubMarkupParser 的 AttributedString | 首次渲染后切换回文件无需重新解析，**最大单项收益** | 0.5天 |
| 缓存 highlighterTheme | 减少 body 求值开销 | 0.5天 |
| 大文件 if/else 替代 ZStack opacity | 减少渲染模式内存 | 0.5天 |
| OutlineService 优化 | 减少数组分配 | 0.5天 |
| 文件变更先查 modificationDate | 避免无变化时全量比较 | 0.5天 |

**总预期**：首次渲染可提升 30-50%，**但滚动卡顿无法根本解决**

### 方案 E：混合方案（小文件 Textual + 大文件 WKWebView + WebView 内 outline）

**思路**：根据文件大小自动切换渲染引擎。渲染模式的 outline 也在 WebView 内部实现。

```
文件 < 30KB → Textual StructuredText + 原生 SwiftUI OutlineView（质量高）
文件 ≥ 30KB → WKWebView（content + outline 一体化 HTML，性能好）
```

**架构变化**：

```
当前架构：
DetailView
  └─ documentContentWithOutline (HStack)
       ├─ documentContentView (ZStack: Raw + Rendered)
       └─ OutlineResizeHandle + OutlineView (SwiftUI)

方案 E 架构：
DetailView
  └─ documentContentWithOutline
       ├─ Raw 模式: documentContentView + OutlineResizeHandle + OutlineView (不变)
       └─ Rendered 大文件: WebViewMarkdownView (HTML content + HTML outline 一体)
```

**关键洞察（用户提出）**：渲染模式的 outline 放在 WebView 内部，消除 outline 相关的 JS Bridge：

| 功能 | 外部 outline（原方案） | WebView 内 outline（改进方案） |
|------|----------------------|---------------------------|
| outline 点击 → 滚动到标题 | JS Bridge: native→JS scrollToLine | ❌ 不需要 — HTML 锚点原生处理 |
| 滚动位置 → 高亮当前标题 | JS Bridge: JS→native 同步位置 | ❌ 不需要 — Intersection Observer 原生处理 |
| 链接点击 | JS Bridge 拦截 | ✅ 仍需 decidePolicyFor（但很简单） |
| 切换 outline 显示/隐藏 | 不需要（原生控制） | ✅ 需要 1 个简单 JS 调用 |
| 模式切换时保持滚动位置 | 需要 JS Bridge | ✅ 仍需（但很简单） |

**JS Bridge 从 5+ 个复杂桥接降到 2-3 个简单调用。**

**优点**：
- 小文件保持最佳渲染质量和原生体验
- 大文件获得流畅滚动
- **滚动定位更精确** — HTML 锚点精确滚动到标题位置，当前方案用「行号 × 平均行高」估算很不准确
- **Intersection Observer 比当前 ScrollHelperView 更可靠** — 当前用 retry 重试机制等待布局完成，Intersection Observer 天然异步且精确
- 架构更清晰 — 每种模式自有完整的渲染+导航体系，互不干扰
- CSS outline 主题映射与主内容复用同一套 CSS 变量

**缺点**：
- 两套渲染引擎维护成本
- 切换阈值附近体验差异
- WKWebView 文本选择体验降级（但阅读器核心是阅读不是选择，影响有限）
- HTML outline 的 resize 不如 NSViewRepresentable ResizeHandle 精细（CSS resize 或 JS 拖拽可接受）
- 两套 outline 的视觉一致性（Raw 模式用 ThemeColors，Rendered 模式用 CSS 变量，需确保视觉接近）

**工作量**：4-5 天（比原评估减少 1-2 天，省去 outline 桥接开发+调试）

### 方案 F：大文件默认 Raw 模式（零风险备选）

**思路**：大文件打开时默认切到 Raw 模式，提示用户可手动切回渲染模式。

**优点**：
- 零风险，零新代码架构
- NSTextView 大文件性能优秀
- 立即可用

**缺点**：
- 丧失渲染模式阅读体验
- 不是真正解决渲染性能问题

**工作量**：0.5 天

---

## 四、推荐路径

### 推荐：方案 D（优化） + 方案 F（零风险备选） → 方案 E（用户洞察后可行性显著提升）

**第一阶段**（2-3天）：方案 D 全部优化项
- 立即缓解首次渲染慢的问题
- 低风险，不改变架构
- 为后续改造争取时间

**过渡方案**（0.5天）：方案 F 大文件默认 Raw 模式
- 大文件（≥30KB）打开时默认切到 Raw 模式
- 顶部提示「大文件已切换到编辑模式以获得更好性能」
- 用户可手动切回渲染模式
- 作为方案 E 实现前的临时措施

**第二阶段**（4-5天）：方案 E 混合引擎（WebView 内 outline）
- 用户洞察 + librarian 技术验证后，可行性评级上调
- 实现 WKWebView Markdown 渲染组件（content + outline 一体化 HTML）
- 仅需 2-3 个简单 JS Bridge 调用（链接点击、outline 显示切换）
- IntersectionObserver 替代当前 ScrollHelperView 重试机制
- CSS Grid 布局 + JS 拖拽 resize sidebar
- 30KB 阈值自动切换
- 统一主题系统（ThemeColors → CSS 变量映射）

### 不推荐方案 B 和 C

- **方案 B**（NSTextView 富文本）：复杂 Markdown 元素（表格、代码高亮、引用块样式）在 NSTextView 中实现质量差，与「安静的阅读器」定位不匹配
- **方案 C**（LazyVStack 分块）：分块边界问题无优雅解，macOS LazyVStack 有 bug，风险高

---

## 五、用户洞察：WebView 内 outline 消除 JS Bridge 痛点

**用户提出**：渲染模式的 outline 也在 WebView 内部实现（HTML 侧边栏），Raw 模式保持原生 SwiftUI outline。这样每种模式都有各自原生的大纲机制，无需跨 Bridge 同步。

### 技术验证结果（librarian 确认）

**结论：完全可行，生产级成熟度。**

| 技术 | 可行性 | 成熟度 |
|------|--------|--------|
| CSS Grid 布局（sidebar + content） | ✅ | ~20 行 CSS，Docusaurus/VitePress 生产验证 |
| IntersectionObserver 滚动追踪 | ✅ | 2019 年起全浏览器基线，无需 polyfill |
| JS 拖拽 resize sidebar | ✅ | mousedown/mousemove/mouseup + CSS 变量，纯 JS |
| outline 点击 → scrollIntoView | ✅ | 纯 JS，无需 native 调用 |
| 状态持久化（宽度、折叠） | ✅ | localStorage 即可，无需 native 通信 |

### JS Bridge 复杂度对比

| 功能 | 外部 outline（原方案） | WebView 内 outline（改进方案） |
|------|----------------------|---------------------------|
| outline 点击 → 滚动到标题 | JS Bridge: native→JS scrollToLine | ❌ **不需要** — HTML 锚点原生处理 |
| 滚动位置 → 高亮当前标题 | JS Bridge: JS→native 同步位置 | ❌ **不需要** — IntersectionObserver 原生处理 |
| 链接点击 | JS Bridge 拦截 | ✅ 仍需 decidePolicyFor（但很简单） |
| 切换 outline 显示/隐藏 | 不需要（原生控制） | ✅ 需要 1 个简单 JS 调用 |
| 模式切换时保持滚动位置 | 需要 JS Bridge | ✅ 仍需（但很简单） |
| sidebar 宽度持久化 | 不需要（原生 UserDefaults） | ✅ 可选 — localStorage 或 postMessage |

**JS Bridge 从 5+ 个复杂桥接降到 2-3 个简单调用。**

### 额外收益

1. **滚动定位更精确** — HTML 锚点精确滚动到标题位置，当前方案用「行号 × 平均行高」估算，对含图片/代码块的文档很不准确
2. **IntersectionObserver 比当前 ScrollHelperView 更可靠** — 当前用 retry 重试机制（最多 20 次 × 0.1s）等待布局完成，IntersectionObserver 天然异步且精确
3. **架构更清晰** — 每种模式自有完整的渲染+导航体系，互不干扰
4. **CSS outline 主题映射与主内容复用同一套 CSS 变量** — 不需要额外 Bridge 同步主题

### 注意事项

1. Raw 模式 outline 保持现状 — 原生 SwiftUI OutlineView + NSScrollView 滚动，已工作良好
2. HTML outline 的 resize — JS mousedown/mousemove/mouseup + CSS 变量，效果不如 NSViewRepresentable ResizeHandle 精细，但可接受
3. 两套 outline 的视觉一致性 — Raw 模式用 ThemeColors，Rendered 模式用 CSS 变量，需确保视觉接近但不要求完全一致
4. IntersectionObserver 的 rootMargin 需微调 — `'-10% 0px -80% 0px'` 模式在标题进入视口顶部 10% 时触发

---

## 六、待确认

1. **方案偏好**：是否接受 WKWebView 作为大文件渲染引擎？还是倾向先用方案 F（大文件默认 Raw）？
2. **阈值设定**：30KB 是否合理？是否需要可配置？
3. **两套引擎的维护成本**：是否可接受？
4. **优先级**：先做方案 D 的优化（立即可改善），还是直接上方案 E？
5. **WKWebView 文本选择体验**：是否可接受比原生稍弱的选择体验？
