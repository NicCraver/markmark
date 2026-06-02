import SwiftUI

/// Markdown 原始文本视图，使用 TextEditor 实现可编辑模式
struct RawMarkdownView: View {
    @Binding var content: String
    var fontSize: CGFloat = 13
    var contentPadding: CGFloat = 20

    var body: some View {
        TextEditor(text: $content)
            .font(.system(size: fontSize, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(contentPadding)
    }
}
