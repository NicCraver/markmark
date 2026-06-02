import SwiftUI
import Textual

// MARK: - NSScrollView 引用捕获

/// 存储 Markdown 内容区 NSScrollView 的弱引用
/// 在 ScrollView 内部通过 ScrollViewCapturer 捕获，在 ScrollHelperView 中直接使用
/// 避免运行时搜索 NSView 层级导致找到错误的 NSScrollView
@MainActor
final class MarkdownScrollViewRef {
    weak var scrollView: NSScrollView?
}

/// 放在 RenderedMarkdownView 的 ScrollView 内部，在 viewDidMoveToWindow 时向上查找并捕获 NSScrollView
/// 由于一定在 ScrollView 内部，superview 向上遍历必然找到正确的 NSScrollView
struct ScrollViewCapturer: NSViewRepresentable {
    let ref: MarkdownScrollViewRef

    func makeNSView(context: Context) -> CaptureNSView {
        CaptureNSView(ref: ref)
    }

    func updateNSView(_ nsView: CaptureNSView, context: Context) {}
}

final class CaptureNSView: NSView {
    let ref: MarkdownScrollViewRef

    init(ref: MarkdownScrollViewRef) {
        self.ref = ref
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // 向上遍历 superview 找到 NSScrollView（一定在 ScrollView 内部，可靠找到）
        var candidate: NSView? = superview
        while let view = candidate {
            if let scrollView = view as? NSScrollView {
                ref.scrollView = scrollView
                return
            }
            candidate = view.superview
        }
    }
}

// MARK: - Markdown 渲染视图

/// Markdown 渲染显示视图，使用 Textual 的 StructuredText
///
/// 性能优化：
/// - 遵循 Equatable 协议 + .equatable() 修饰符，仅在 content/fileURL/padding 变化时重渲染
/// - 父视图的 Observable 属性变化（如 sidebarWidth 拖拽等）不会触发重渲染
/// - 使用 ScrollView + VStack 而非 LazyVStack（StructuredText 是单一视图，无法分块懒加载）
struct RenderedMarkdownView: View, Equatable {
    let content: String
    let fileURL: URL?
    var contentPadding: CGFloat = 20
    var scrollViewRef: MarkdownScrollViewRef

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                StructuredText(markdown: content)
                    .textual.structuredTextStyle(.gitHub)
                    .textual.textSelection(.enabled)
                    .padding(contentPadding)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ScrollViewCapturer(ref: scrollViewRef))
        }
        .scrollIndicators(.automatic)
        .id(fileURL)
        .environment(\.openURL, OpenURLAction { url in
            NSWorkspace.shared.open(url)
            return .handled
        })
    }

    // MARK: - Equatable

    nonisolated static func == (lhs: RenderedMarkdownView, rhs: RenderedMarkdownView) -> Bool {
        lhs.content == rhs.content
            && lhs.fileURL == rhs.fileURL
            && lhs.contentPadding == rhs.contentPadding
        // scrollViewRef 不参与比较（引用类型，不影响内容渲染）
    }
}

// MARK: - 滚动辅助视图

/// 透明 NSViewRepresentable，使用预捕获的 NSScrollView 引用执行滚动
/// 基于 lineNumber 估算目标 Y 偏移，将标题定位在可见区域的 1/3 处
struct ScrollHelperView: NSViewRepresentable {
    typealias NSViewType = ScrollHelperNSView

    let scrollToLine: Int?
    let scrollViewRef: MarkdownScrollViewRef
    let content: String

    func makeNSView(context: Context) -> ScrollHelperNSView {
        let view = ScrollHelperNSView()
        view.content = content
        return view
    }

    func updateNSView(_ nsView: ScrollHelperNSView, context: Context) {
        nsView.content = content

        if let line = scrollToLine {
            // 延迟一帧执行，确保布局已完成
            DispatchQueue.main.async {
                nsView.scrollToLine(line, scrollViewRef: scrollViewRef)
            }
        }
    }
}

final class ScrollHelperNSView: NSView {
    var content: String?

    /// 使用预捕获的 NSScrollView 引用滚动到指定行号
    func scrollToLine(_ lineNumber: Int, scrollViewRef: MarkdownScrollViewRef) {
        guard let scrollView = scrollViewRef.scrollView,
              let content = content else { return }

        let totalLines = content.components(separatedBy: "\n").count
        guard totalLines > 0 else { return }

        let documentHeight = scrollView.documentView?.frame.height ?? 0
        let visibleHeight = scrollView.visibleRect.height

        // 估算每行平均高度
        let avgLineHeight = documentHeight / CGFloat(totalLines)

        // 目标 Y 位置（将标题定位在可见区域 1/3 处）
        let targetY = CGFloat(lineNumber) * avgLineHeight - visibleHeight / 3.0
        let clampedY = max(0, min(targetY, documentHeight - visibleHeight))

        // 执行动画滚动
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            scrollView.contentView.animator().setBoundsOrigin(
                NSPoint(x: scrollView.contentView.bounds.origin.x, y: clampedY)
            )
        }
    }
}

// MARK: - EquatableView 包装

/// 将 RenderedMarkdownView 包装为 EquatableView，防止无关状态变化时重渲染
/// ScrollHelperView 放在 EquatableView 外部，独立响应 scrollToLine 变化
struct EquatableRenderedMarkdownView: View, Equatable {
    let content: String
    let fileURL: URL?
    let contentPadding: CGFloat
    var scrollToLine: Int?
    let scrollViewRef: MarkdownScrollViewRef

    var body: some View {
        EquatableView(content: RenderedMarkdownView(
            content: content,
            fileURL: fileURL,
            contentPadding: contentPadding,
            scrollViewRef: scrollViewRef
        ))
        .background(
            // ScrollHelperView 在 EquatableView 外部，使用预捕获的 NSScrollView 引用
            ScrollHelperView(scrollToLine: scrollToLine, scrollViewRef: scrollViewRef, content: content)
        )
    }

    nonisolated static func == (lhs: EquatableRenderedMarkdownView, rhs: EquatableRenderedMarkdownView) -> Bool {
        lhs.content == rhs.content
            && lhs.fileURL == rhs.fileURL
            && lhs.contentPadding == rhs.contentPadding
            && lhs.scrollToLine == rhs.scrollToLine
        // scrollViewRef 不参与比较（引用类型，同一实例）
    }
}
