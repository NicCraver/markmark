import SwiftUI

/// Markdown 原始文本视图，使用 NSTextView 实现语法高亮着色
/// 像 VS Code / Sublime Text 一样对 Markdown 语法元素进行着色渲染
struct RawMarkdownView: View {
    @Binding var content: String
    var fontSize: CGFloat = 13
    var contentPadding: CGFloat = 20
    var scrollToLine: Int?
    var fileURL: URL?
    /// 是否处于活跃状态（Raw 模式），用于自动获取焦点
    var isActive: Bool = false
    var isFindBarVisible: Bool = false
    var searchRef: TextViewSearchRef?
    var onCursorLineNumberChanged: ((Int) -> Void)?
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        SyntaxHighlightedEditor(
            content: $content,
            fontSize: fontSize,
            contentPadding: contentPadding,
            scrollToLine: scrollToLine,
            themeColors: themeColors,
            fileURL: fileURL,
            isActive: isActive,
            searchRef: searchRef,
            isFindBarVisible: isFindBarVisible,
            onCursorLineNumberChanged: onCursorLineNumberChanged
        )
        .background(themeColors.surface)
    }
}
