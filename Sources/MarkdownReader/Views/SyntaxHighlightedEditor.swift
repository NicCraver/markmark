import SwiftUI
import AppKit
import ObjectiveC

// MARK: - 搜索高亮引用

@MainActor
final class TextViewSearchRef {
    weak var textView: HighlightableTextView?
    private var highlightedRanges: [NSRange] = []
    private var highlightColor: NSColor = NSColor.systemOrange.withAlphaComponent(0.3)
    private var currentMatchColor: NSColor = NSColor.systemOrange.withAlphaComponent(0.6)
    var currentMatchIndex: Int = -1

    func reapplySearchHighlights(matchRanges: [NSRange], currentIndex: Int) {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return }

        highlightedRanges = matchRanges
        currentMatchIndex = currentIndex

        textView.suppressAutoScroll = true
        defer { textView.suppressAutoScroll = false }

        textView.undoManager?.disableUndoRegistration()
        defer { textView.undoManager?.enableUndoRegistration() }

        // 使用 beginEditing/endEditing 批量更新，防止每次 addAttribute 触发 textDidChange
        // 导致 reapplyHighlights 被反复调用，造成搜索高亮被语法高亮覆盖
        textStorage.beginEditing()
        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
        let storageLength = textStorage.length
        for (index, range) in matchRanges.enumerated() {
            guard range.location >= 0,
                  range.location + range.length <= storageLength else { continue }
            let color: NSColor = index == currentIndex ? currentMatchColor : highlightColor
            textStorage.addAttribute(.backgroundColor, value: color, range: range)
        }
        textStorage.endEditing()
    }

    func clearSearchHighlights() {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return }

        highlightedRanges = []
        currentMatchIndex = -1

        textView.undoManager?.disableUndoRegistration()
        defer { textView.undoManager?.enableUndoRegistration() }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        textStorage.removeAttribute(.backgroundColor, range: fullRange)
    }

    func selectMatch(at index: Int, in ranges: [NSRange]) {
        guard let textView = textView,
              index >= 0, index < ranges.count else { return }
        let range = ranges[index]
        let storageLength = textView.textStorage?.length ?? 0
        guard range.location >= 0,
              range.location + range.length <= storageLength else { return }
        currentMatchIndex = index
        textView.setSelectedRange(range)
        textView.scrollRangeToVisible(range)
    }

    func replaceCurrentMatch(at range: NSRange, with replacement: String) -> NSRange? {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return nil }
        let storageLength = textStorage.length
        guard range.location >= 0,
              range.location + range.length <= storageLength else { return nil }
        textStorage.replaceCharacters(in: range, with: replacement)
        let newLength = (replacement as NSString).length
        return NSRange(location: range.location, length: newLength)
    }

    func replaceAllMatches(ranges: [NSRange], with replacement: String) -> Int {
        guard let textView = textView,
              let textStorage = textView.textStorage else { return 0 }
        var count = 0
        for range in ranges.reversed() {
            let storageLength = textStorage.length
            guard range.location >= 0,
                  range.location + range.length <= storageLength else { continue }
            textStorage.replaceCharacters(in: range, with: replacement)
            count += 1
        }
        return count
    }

    func allMatchRanges() -> [NSRange] { highlightedRanges }
}

// MARK: - 全局 Per-File UndoManager 引用

/// 当前活跃文件的 UndoManager，供 NSWindow swizzled getter 访问
/// nonisolated(unsafe) 确保 ObjC runtime 可从任何线程读取
nonisolated(unsafe) var _activePerFileUndoManager: UndoManager?

// MARK: - NSWindow undoManager Swizzling

extension NSWindow {
    private static var _hasSwizzled = false

    /// 替换 NSWindow.undoManager getter，使其返回 per-file UndoManager
    /// 这是让 Edit 菜单 Undo/Redo 正确工作的关键
    /// NSWindow.undoManager 是只读属性，无 setter，windowWillReturnUndoManager: 不被 SwiftUI 调用
    /// 唯一可靠的方式是 method swizzling
    static func swizzleUndoManager() {
        guard !_hasSwizzled else { return }
        _hasSwizzled = true

        let original = class_getInstanceMethod(NSWindow.self, #selector(getter: undoManager))
        let swizzled = class_getInstanceMethod(NSWindow.self, #selector(_swizzled_undoManager))
        if let original, let swizzled {
            method_exchangeImplementations(original, swizzled)
        }
    }

    /// Swizzled undoManager getter — 返回 per-file UndoManager（如果存在）
    /// 由于 method_exchangeImplementations，调用 self._swizzled_undoManager() 实际调用原始实现
    @objc private func _swizzled_undoManager() -> UndoManager? {
        if Thread.isMainThread, let um = _activePerFileUndoManager {
            return um
        }
        // 调用原始实现（swizzling 交换了实现，所以这里实际调用原始方法）
        return self._swizzled_undoManager()
    }
}

// MARK: - Per-File UndoManager Provider

/// 全局 UndoManager 提供者，管理 per-file undo 历史
/// 通过 NSWindow swizzled getter 和 NSTextViewDelegate.undoManager(for:)
/// 确保菜单验证和文本编辑使用同一个 per-file UndoManager
@MainActor
final class UndoManagerProvider: NSObject {
    static let shared = UndoManagerProvider()

    /// Per-file UndoManager 池（nonisolated(unsafe) 以便 swizzled getter 访问）
    nonisolated(unsafe) private var _undoManagers: [URL: UndoManager] = [:]

    /// 当前活跃文件的 URL
    var activeFileURL: URL?
    nonisolated(unsafe) private var _activeFileURL: URL?

    /// 当前活跃文件的 UndoManager
    var activeUndoManager: UndoManager {
        if let url = activeFileURL, let existing = _undoManagers[url] {
            return existing
        }
        // 创建新的 UndoManager
        let manager = UndoManager()
        manager.levelsOfUndo = 100
        if let url = activeFileURL {
            _undoManagers[url] = manager
        }
        return manager
    }

    /// 获取指定文件的 UndoManager
    func undoManager(for url: URL?) -> UndoManager? {
        guard let url = url else { return nil }
        if let existing = _undoManagers[url] {
            return existing
        }
        let manager = UndoManager()
        manager.levelsOfUndo = 100
        _undoManagers[url] = manager
        return manager
    }

    /// 切换活跃文件
    func switchFile(to url: URL?) {
        activeFileURL = url
        _activeFileURL = url
        // 确保 UndoManager 存在
        if let url = url, _undoManagers[url] == nil {
            let manager = UndoManager()
            manager.levelsOfUndo = 100
            _undoManagers[url] = manager
        }
        // 更新全局引用（供 NSWindow swizzled getter 使用）
        _activePerFileUndoManager = url.flatMap { _undoManagers[$0] }
        // 清理过多的 UndoManager
        cleanupIfNeeded()
    }

    /// 清除所有 per-file UndoManager 的 undo 动作
    /// 当 NSTextView 被释放时调用，防止悬空指针 crash
    /// NSUndoManager 不 retain invocation targets，如果 target 被释放后触发 undo 会 crash
    func removeAllActions() {
        for (_, um) in _undoManagers {
            um.removeAllActions()
        }
        _activePerFileUndoManager = nil
    }

    /// 清理过多的 UndoManager（保留最近 20 个）
    private func cleanupIfNeeded() {
        guard _undoManagers.count > 20 else { return }
        let keysToRemove = _undoManagers.keys.filter { $0 != activeFileURL }
        for key in keysToRemove.prefix(_undoManagers.count - 10) {
            _undoManagers.removeValue(forKey: key)
        }
    }
}

// MARK: - 可控滚动文本视图

/// NSTextView 子类，支持在高亮期间抑制自动滚动
/// 防止 setSelectedRange / 布局变化触发 scrollRangeToVisible 导致跳动
class HighlightableTextView: NSTextView {
    var suppressAutoScroll = false

    // 不重写 undoManager — 通过 NSTextViewDelegate.undoManager(for:) 和
    // NSWindowDelegate.windowWillReturnUndoManager: 提供 per-file UndoManager
    // 这确保文本编辑和菜单验证使用同一个 UndoManager 实例

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func scrollRangeToVisible(_ range: NSRange) {
        if !suppressAutoScroll {
            super.scrollRangeToVisible(range)
        }
    }

    deinit {
        // 安全网：当 NSTextView 被释放时，清除所有 per-file UndoManager 的 undo 动作
        // NSUndoManager 不 retain invocation targets，如果 NSTextView 被释放后
        // UndoManager 仍有引用它的 undo 动作，触发 undo 时会访问悬空指针导致 crash
        // 使用异步调度因为 deinit 不能调用 @MainActor 方法
        DispatchQueue.main.async {
            UndoManagerProvider.shared.removeAllActions()
        }
    }
}

// MARK: - 语法高亮编辑器

/// 基于 NSTextView 的语法高亮编辑器
/// 支持 Markdown 语法着色、主题色适配、滚动到指定行
struct SyntaxHighlightedEditor: NSViewRepresentable {
    @Binding var content: String
    var fontSize: CGFloat = 13
    var contentPadding: CGFloat = 20
    var scrollToLine: Int?
    var themeColors: ThemeColors
    /// 当前文件 URL，用于 per-file undo 管理
    var fileURL: URL?
    /// 是否处于活跃状态（Raw 模式），用于自动获取焦点
    var isActive: Bool = false
    var searchRef: TextViewSearchRef?
    /// 查找面板是否可见，可见时不抢占焦点
    var isFindBarVisible: Bool = false
    /// 光标行号变化回调（0-based 行号）
    var onCursorLineNumberChanged: ((Int) -> Void)?

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

        let textView = HighlightableTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.usesFindBar = false
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
        textView.backgroundColor = .clear  // 显式设置透明背景，防止 appearance 变化时 AppKit 重置为不透明
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

        // 初始内容 — 使用 textStorage API + disableUndoRegistration 避免 undo 记录
        let um = UndoManagerProvider.shared.undoManager(for: fileURL)
        um?.disableUndoRegistration()
        if let textStorage = textView.textStorage {
            textStorage.replaceCharacters(in: NSRange(location: 0, length: 0), with: content)
        } else {
            textView.string = content
        }
        um?.enableUndoRegistration()

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
        searchRef?.textView = textView

        // 记录当前 appearance，后续 updateNSView 中检测变化
        context.coordinator.lastAppearanceToken = NSApp.effectiveAppearance.description

        // 初始化 UndoManagerProvider 的活跃文件
        UndoManagerProvider.shared.switchFile(to: fileURL)

        // 如果处于活跃状态，自动获取焦点
        if isActive {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? HighlightableTextView else { return }

        // 检测文件切换：更新 UndoManagerProvider 的活跃文件
        if context.coordinator.currentFileURL != fileURL {
            UndoManagerProvider.shared.switchFile(to: fileURL)
            context.coordinator.currentFileURL = fileURL
        }

        // 更新内容（仅在内容确实不同时）
        let currentContent = textView.string
        if currentContent != content {
            // 使用 textStorage API 更新内容，禁用 undo 注册
            // 避免程序化内容更新产生 undo 记录
            textView.undoManager?.disableUndoRegistration()
            defer { textView.undoManager?.enableUndoRegistration() }

            if let textStorage = textView.textStorage {
                let fullRange = NSRange(location: 0, length: textStorage.length)
                textStorage.beginEditing()
                textStorage.replaceCharacters(in: fullRange, with: content)
                textStorage.endEditing()
            } else {
                textView.string = content
            }

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

        // 更新插入点颜色和文字颜色
        textView.insertionPointColor = themeColors.accent.nsColor
        textView.textColor = themeColors.ink.nsColor
        // 防御性重置：AppKit 可能在 appearance 变化时将 drawsBackground 重置为 true
        // 或将 backgroundColor 重置为不透明色，导致文字被覆盖不可见
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        // 检测 appearance 变化（NSApp.appearance 被设置时 AppKit 会重置 NSTextView 的 textColor）
        context.coordinator.checkAppearanceChange()

        // 主题变化时重新应用语法高亮（内容/字号未变但颜色可能不同）
        if context.coordinator.previousThemeColors != themeColors {
            let syntaxColors = deriveSyntaxColors(from: themeColors)
            MarkdownSyntaxHighlighter.applyHighlights(
                to: textView,
                text: textView.string,
                colors: syntaxColors,
                fontSize: fontSize
            )
            context.coordinator.previousThemeColors = themeColors
        }

        // 更新边距（仅在值变化时更新，避免不必要的布局计算）
        let currentInset = textView.textContainerInset
        let newInset = NSSize(width: contentPadding, height: contentPadding)
        if abs(currentInset.width - newInset.width) > 0.01 || abs(currentInset.height - newInset.height) > 0.01 {
            textView.textContainerInset = newInset
        }

        // First responder 管理：切换到 Raw 模式时自动获取焦点
        // 查找面板可见时不抢占焦点，避免搜索输入框失去焦点
        if isActive, !isFindBarVisible, let window = textView.window, window.firstResponder !== textView {
            DispatchQueue.main.async {
                window.makeFirstResponder(textView)
            }
        }

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
        weak var textView: HighlightableTextView?
        weak var scrollView: NSScrollView?
        private var highlightWorkItem: DispatchWorkItem?
        var currentFileURL: URL?
        var previousThemeColors: ThemeColors?
        /// 上次记录的 appearance token，用于检测 appearance 变化
        var lastAppearanceToken: String?

        init(_ parent: SyntaxHighlightedEditor) {
            self.parent = parent
        }

        /// 检查 appearance 是否变化，如果变化则重新应用颜色
        /// 在 updateNSView 中调用，因为 SwiftUI 不会在 appearance 变化时主动调用 updateNSView
        @MainActor
        func checkAppearanceChange() {
            let currentToken = NSApp.effectiveAppearance.description
            guard currentToken != lastAppearanceToken else { return }
            lastAppearanceToken = currentToken

            // appearance 变化时重新应用文字颜色和语法高亮
            // AppKit 在 NSApp.appearance 变化时会自动重置 NSTextView 的以下属性：
            // - textColor → 系统默认色（可能和背景色相同导致文字不可见）
            // - drawsBackground → 可能被重置为 true
            // - backgroundColor → 可能被重置为不透明的系统色
            guard let textView else { return }
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            textView.textColor = parent.themeColors.ink.nsColor
            textView.insertionPointColor = parent.themeColors.accent.nsColor
            let syntaxColors = parent.deriveSyntaxColors(from: parent.themeColors)
            MarkdownSyntaxHighlighter.applyHighlights(
                to: textView,
                text: textView.string,
                colors: syntaxColors,
                fontSize: parent.fontSize
            )
        }

        /// NSTextViewDelegate — 为文本视图提供 per-file UndoManager
        /// 此方法返回的 UndoManager 同时也是 windowWillReturnUndoManager: 返回的实例
        /// 确保文本编辑和菜单验证使用同一个 UndoManager
        func undoManager(for view: NSTextView) -> UndoManager? {
            return UndoManagerProvider.shared.activeUndoManager
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = textView else { return }
            let newContent = textView.string

            // 更新绑定
            parent.content = newContent

            notifyCursorLineNumber(textView)

            // 防抖高亮：延迟 50ms 重新高亮，避免每次按键都触发
            highlightWorkItem?.cancel()
            let item = DispatchWorkItem { [weak self] in
                self?.reapplyHighlights()
            }
            highlightWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = textView else { return }
            notifyCursorLineNumber(textView)
        }

        @MainActor
        private func notifyCursorLineNumber(_ textView: NSTextView) {
            let location = textView.selectedRange().location
            let text = textView.string
            // 1-based line number, consistent with HTML data-line and OutlineItem.lineNumber
            let lineNumber = text[..<text.index(text.startIndex, offsetBy: min(location, text.count))].components(separatedBy: "\n").count
            parent.onCursorLineNumberChanged?(lineNumber)
        }

        @MainActor
        private func reapplyHighlights() {
            guard let textView = textView,
                  let scrollView = scrollView,
                  let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else { return }

            let syntaxColors = parent.deriveSyntaxColors(from: parent.themeColors)

            // 抑制自动滚动，防止高亮期间 setSelectedRange / 布局变化导致跳动
            textView.suppressAutoScroll = true
            defer { textView.suppressAutoScroll = false }

            // 保存选中范围
            let selectedRange = textView.selectedRange()

            // 保存滚动位置：记录第一个可见字符的位置和垂直偏移
            let visibleRect = textView.visibleRect
            let textContainerOrigin = textView.textContainerOrigin

            // 将可见区域从文本视图坐标转换为文本容器坐标
            let containerVisibleRect = NSRect(
                x: visibleRect.origin.x - textContainerOrigin.x,
                y: visibleRect.origin.y - textContainerOrigin.y,
                width: visibleRect.width,
                height: visibleRect.height
            )

            // 获取可见区域对应的字符范围
            let visibleGlyphRange = layoutManager.glyphRange(forBoundingRect: containerVisibleRect, in: textContainer)
            let visibleCharRange = layoutManager.characterRange(forGlyphRange: visibleGlyphRange, actualGlyphRange: nil)
            let firstVisibleCharLocation = visibleCharRange.location

            // 计算第一个可见字符在文本视图坐标系中的 Y 坐标
            let firstCharGlyphRange = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: firstVisibleCharLocation, length: 0),
                actualCharacterRange: nil
            )
            let firstCharRect = layoutManager.boundingRect(forGlyphRange: firstCharGlyphRange, in: textContainer)
            let firstCharYInView = firstCharRect.origin.y + textContainerOrigin.y

            // 计算第一个可见字符相对于可见区域顶部的偏移量
            let verticalOffset = firstCharYInView - visibleRect.origin.y

            // 应用语法高亮
            MarkdownSyntaxHighlighter.applyHighlights(
                to: textView,
                text: textView.string,
                colors: syntaxColors,
                fontSize: parent.fontSize
            )

            // 确保可见区域的布局已完成（而非仅 1 个字符）
            layoutManager.ensureLayout(forCharacterRange: visibleCharRange)

            // 基于字符位置恢复滚动位置（在恢复选中范围之前，避免 setSelectedRange 触发二次滚动）
            let restoredGlyphRange = layoutManager.glyphRange(
                forCharacterRange: NSRange(location: firstVisibleCharLocation, length: 0),
                actualCharacterRange: nil
            )
            let restoredRect = layoutManager.boundingRect(forGlyphRange: restoredGlyphRange, in: textContainer)
            let targetY = restoredRect.origin.y + textContainerOrigin.y - verticalOffset

            let visibleHeight = scrollView.visibleRect.height
            let documentHeight = scrollView.documentView?.frame.height ?? 0
            let clampedY = max(0, min(targetY, documentHeight - visibleHeight))

            scrollView.contentView.setBoundsOrigin(
                NSPoint(x: scrollView.contentView.bounds.origin.x, y: clampedY)
            )
            scrollView.reflectScrolledClipView(scrollView.contentView)

            // 恢复选中范围（此时滚动位置已固定，suppressAutoScroll 防止二次跳动）
            textView.setSelectedRange(selectedRange)

            // 重新叠加搜索高亮（语法高亮会 setAttributes 全文本重置，覆盖搜索高亮）
            // 延迟一帧执行，确保语法高亮的 endEditing 已完成，避免被覆盖
            if let searchRef = parent.searchRef, !searchRef.allMatchRanges().isEmpty {
                DispatchQueue.main.async {
                    searchRef.reapplySearchHighlights(
                        matchRanges: searchRef.allMatchRanges(),
                        currentIndex: searchRef.currentMatchIndex
                    )
                }
            }

            // 延迟再确认一次滚动位置，防止布局管理器异步调整
            let finalY = clampedY
            DispatchQueue.main.async {
                guard let scrollView = self.scrollView else { return }
                let currentY = scrollView.contentView.bounds.origin.y
                if abs(currentY - finalY) > 1.0 {
                    scrollView.contentView.setBoundsOrigin(
                        NSPoint(x: scrollView.contentView.bounds.origin.x, y: finalY)
                    )
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }
        }
    }
}

// MARK: - SwiftUI Color → NSColor 转换

extension Color {
    // NSColor(SwiftUI.Color) 创建的是"目录颜色"（catalog color），会根据当前
    // NSAppearance 懒加载解析。codesign --deep 重签名可能破坏 SwiftUI 颜色目录签名，
    // 导致解析失败返回错误色值（如 .clear 或背景色），使文字不可见。
    // 显式转换为 sRGB 色彩空间创建固定颜色，消除动态解析问题。
    var nsColor: NSColor {
        let resolved = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.black
        return NSColor(red: resolved.redComponent, green: resolved.greenComponent,
                       blue: resolved.blueComponent, alpha: resolved.alphaComponent)
    }
}

// MARK: - NSColor 感知亮度

extension NSColor {
    var perceivedBrightness: CGFloat {
        let srgb = usingColorSpace(.sRGB) ?? self
        return 0.299 * srgb.redComponent + 0.587 * srgb.greenComponent + 0.114 * srgb.blueComponent
    }
}
