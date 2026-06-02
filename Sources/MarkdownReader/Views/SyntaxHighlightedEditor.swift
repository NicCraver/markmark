import SwiftUI
import AppKit

// MARK: - 语法高亮编辑器

/// 基于 NSTextView 的语法高亮编辑器
/// 支持 Markdown 语法着色、主题色适配、滚动到指定行
struct SyntaxHighlightedEditor: NSViewRepresentable {
    @Binding var content: String
    var fontSize: CGFloat = 13
    var contentPadding: CGFloat = 20
    var scrollToLine: Int?
    var themeColors: ThemeColors

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        // 手动创建 NSScrollView + NSTextView
        // 不使用 NSTextView.scrollableTextView() 工厂方法，避免其自带约束与 SwiftUI 布局冲突
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.smartInsertDeleteEnabled = false
        textView.isSelectable = true
        textView.isEditable = true
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.insertionPointColor = themeColors.accent.nsColor

        // 让文本容器宽度跟随 textView 宽度自动调整
        if let textContainer = textView.textContainer {
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        }

        // 设置默认字体和颜色
        let defaultFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = defaultFont
        textView.textColor = themeColors.ink.nsColor

        // 初始内容
        textView.string = content

        // 组装 scrollView + textView
        scrollView.documentView = textView

        // 设置边距
        textView.textContainerInset = NSSize(width: contentPadding, height: contentPadding)

        // 应用初始高亮
        let syntaxColors = deriveSyntaxColors(from: themeColors)
        MarkdownSyntaxHighlighter.applyHighlights(
            to: textView,
            text: content,
            colors: syntaxColors,
            fontSize: fontSize
        )

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // 更新内容（仅在非编辑状态下）
        let currentContent = textView.string
        if currentContent != content {
            textView.string = content
            let syntaxColors = deriveSyntaxColors(from: themeColors)
            MarkdownSyntaxHighlighter.applyHighlights(
                to: textView,
                text: content,
                colors: syntaxColors,
                fontSize: fontSize
            )
        }

        // 更新字体大小
        let currentFont = textView.font ?? NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        if abs(currentFont.pointSize - fontSize) > 0.01 {
            let syntaxColors = deriveSyntaxColors(from: themeColors)
            MarkdownSyntaxHighlighter.applyHighlights(
                to: textView,
                text: textView.string,
                colors: syntaxColors,
                fontSize: fontSize
            )
        }

        // 更新插入点颜色
        textView.insertionPointColor = themeColors.accent.nsColor

        // 更新边距
        textView.textContainerInset = NSSize(width: contentPadding, height: contentPadding)

        // 滚动到指定行
        if let line = scrollToLine {
            DispatchQueue.main.async {
                scrollToLineInTextView(textView, line: line, content: textView.string)
            }
        }
    }

    // MARK: - 颜色转换

    /// 从 ThemeColors 派生 SyntaxColors
    private func deriveSyntaxColors(from tc: ThemeColors) -> SyntaxColors {
        let surface = tc.surface.nsColor
        let ink = tc.ink.nsColor
        let accent = tc.accent.nsColor
        let success = tc.success.nsColor
        let danger = tc.danger.nsColor

        let isDark = tc.surface.nsColor.perceivedBrightness < tc.ink.nsColor.perceivedBrightness

        return SyntaxColors.from(
            surface: surface,
            ink: ink,
            accent: accent,
            success: success,
            danger: danger,
            isDark: isDark
        )
    }

    // MARK: - 滚动到行

    private func scrollToLineInTextView(_ textView: NSTextView, line: Int, content: String) {
        let lines = content.components(separatedBy: "\n")
        guard line < lines.count else { return }

        var charOffset = 0
        for i in 0..<line {
            charOffset += lines[i].count + 1
        }

        let range = NSRange(location: charOffset, length: 0)
        textView.scrollRangeToVisible(range)

        // 1/3 位置效果
        if let scrollView = textView.enclosingScrollView,
           let layoutManager = textView.layoutManager,
           let textContainer = textView.textContainer {

            let glyphRange = layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            let textContainerOrigin = textView.textContainerOrigin
            let targetY = rect.origin.y + textContainerOrigin.y

            let visibleHeight = scrollView.visibleRect.height
            let adjustedY = max(0, targetY - visibleHeight / 3.0)

            let documentHeight = scrollView.documentView?.frame.height ?? 0
            let clampedY = min(adjustedY, documentHeight - visibleHeight)

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.3
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                scrollView.contentView.animator().setBoundsOrigin(
                    NSPoint(x: scrollView.contentView.bounds.origin.x, y: clampedY)
                )
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: SyntaxHighlightedEditor
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        private var highlightWorkItem: DispatchWorkItem?

        init(_ parent: SyntaxHighlightedEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            let newContent = textView.string

            // 更新绑定
            parent.content = newContent

            // 防抖高亮：延迟 50ms 重新高亮，避免每次按键都触发
            highlightWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.reapplyHighlights()
            }
            highlightWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
        }

        @MainActor
        private func reapplyHighlights() {
            guard let textView = textView else { return }
            let syntaxColors = parent.deriveSyntaxColors(from: parent.themeColors)

            let selectedRange = textView.selectedRange()
            let visibleRange = textView.visibleRect

            MarkdownSyntaxHighlighter.applyHighlights(
                to: textView,
                text: textView.string,
                colors: syntaxColors,
                fontSize: parent.fontSize
            )

            textView.setSelectedRange(selectedRange)

            guard let scrollView = scrollView else { return }
            let currentVisible = scrollView.contentView.bounds
            if currentVisible != visibleRange {
                scrollView.contentView.setBoundsOrigin(visibleRange.origin)
            }
        }
    }
}

// MARK: - SwiftUI Color → NSColor 转换

extension Color {
    var nsColor: NSColor {
        NSColor(self)
    }
}

// MARK: - NSColor 感知亮度

extension NSColor {
    var perceivedBrightness: CGFloat {
        let srgb = usingColorSpace(.sRGB) ?? self
        return 0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent
    }
}
