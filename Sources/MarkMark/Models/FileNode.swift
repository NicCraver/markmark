import Foundation

/// 文件/目录节点模型，用于构建目录树
struct FileNode: Identifiable, Hashable {
    let id: URL
    let name: String
    let path: URL
    let isDirectory: Bool
    let isMarkdown: Bool
    var children: [FileNode]?

    init(
        name: String,
        path: URL,
        isDirectory: Bool,
        isMarkdown: Bool = false,
        children: [FileNode]? = nil
    ) {
        self.id = path
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.isMarkdown = isMarkdown
        self.children = children
    }

    /// 目录节点的子节点是否已加载（懒加载标记）
    var isChildrenLoaded: Bool {
        children != nil
    }
}
