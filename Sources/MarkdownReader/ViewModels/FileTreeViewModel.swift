import SwiftUI

/// 目录树视图模型，管理目录树数据和展开/折叠状态
@MainActor
@Observable
final class FileTreeViewModel {

    // MARK: - 状态

    /// 目录树根节点
    var nodes: [FileNode] = []

    /// 已展开的目录 URL 集合
    var expandedDirs: Set<URL> = []

    /// 当前选中的文件 URL
    var selectedFileURL: URL?

    /// 是否正在加载
    var isLoading: Bool = false

    /// 错误信息
    var errorMessage: String?

    /// 是否为空目录（无 Markdown 文件）
    var isEmptyDirectory: Bool = false

    // MARK: - 依赖

    private let fileService: FileService

    /// 设置模型（用于读取文件树过滤设置）
    var settings: SettingsModel

    // MARK: - 初始化

    init(fileService: FileService = FileService(), settings: SettingsModel = SettingsModel.shared) {
        self.fileService = fileService
        self.settings = settings
    }

    // MARK: - 方法

    /// 加载目录树
    /// - Parameter directory: 根目录 URL
    func loadDirectory(_ directory: URL) async {
        isLoading = true
        errorMessage = nil
        isEmptyDirectory = false

        do {
            let children = try await fileService.scanDirectory(
                directory,
                showHiddenFiles: settings.showHiddenFiles,
                showNonMarkdownFiles: settings.showNonMarkdownFiles
            )
            isEmptyDirectory = !fileService.directoryContainsMarkdown(
                directory,
                showHiddenFiles: settings.showHiddenFiles
            )

            // 根目录作为一级节点显示，子目录内容作为其 children
            let rootNode = FileNode(
                name: directory.lastPathComponent,
                path: directory,
                isDirectory: true,
                children: children
            )
            nodes = [rootNode]

            // 默认展开根目录（显示第一级目录和文件）
            expandedDirs.insert(directory)
        } catch {
            errorMessage = error.localizedDescription
            nodes = []
        }

        isLoading = false
    }

    /// 切换目录展开/折叠
    func toggleExpand(_ url: URL) {
        if expandedDirs.contains(url) {
            expandedDirs.remove(url)
        } else {
            expandedDirs.insert(url)
        }
    }

    /// 判断目录是否已展开
    func isExpanded(_ url: URL) -> Bool {
        expandedDirs.contains(url)
    }

    /// 选中文件（包括非 .md 文件，以触发错误提示）
    func selectFile(_ node: FileNode) {
        if node.isDirectory { return }
        selectedFileURL = node.path
    }

    /// 获取扁平化的可见节点列表（用于键盘导航）
    func flattenedVisibleNodes() -> [FileNode] {
        var result: [FileNode] = []
        for node in nodes {
            result.append(node)
            if node.isDirectory, expandedDirs.contains(node.path), let children = node.children {
                result.append(contentsOf: flattenChildren(children))
            }
        }
        return result
    }

    /// 在扁平列表中移动选中项
    func moveSelection(direction: Int) -> FileNode? {
        let flat = flattenedVisibleNodes()
        guard !flat.isEmpty else { return nil }

        let currentIndex: Int
        if let currentURL = selectedFileURL,
           let idx = flat.firstIndex(where: { $0.path == currentURL }) {
            currentIndex = idx
        } else {
            currentIndex = -1
        }

        let newIndex = max(0, min(flat.count - 1, currentIndex + direction))
        let node = flat[newIndex]

        if node.isDirectory {
            toggleExpand(node.path)
        } else {
            selectFile(node)
        }

        return node
    }

    // MARK: - 私有方法

    private func flattenChildren(_ children: [FileNode]) -> [FileNode] {
        var result: [FileNode] = []
        for node in children {
            result.append(node)
            if node.isDirectory, expandedDirs.contains(node.path), let subChildren = node.children {
                result.append(contentsOf: flattenChildren(subChildren))
            }
        }
        return result
    }
}
