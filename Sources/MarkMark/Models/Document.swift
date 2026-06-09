import Foundation

/// 文档模型，表示当前打开的 Markdown 文档
struct Document: Identifiable {
    let id: URL
    let content: String
    let filePath: URL

    init(content: String, filePath: URL) {
        self.id = filePath
        self.content = content
        self.filePath = filePath
    }
}
