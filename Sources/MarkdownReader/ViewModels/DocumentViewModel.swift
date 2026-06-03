import SwiftUI

/// 文档视图模型，管理当前文档状态和文件读取
@MainActor
@Observable
final class DocumentViewModel {

    // MARK: - 状态

    /// 当前文档内容
    var content: String = ""

    /// 当前文件 URL
    var currentFileURL: URL?

    /// 当前文件名
    var fileName: String = ""

    /// 显示模式
    var displayMode: DisplayMode = .rendered

    /// 是否是首次设置显示模式（用于在加载新文件时应用默认显示模式）
    private var isFirstFile: Bool = true

    /// 是否正在加载
    var isLoading: Bool = false

    /// 错误信息
    var fileError: FileError?

    /// 是否有文档打开
    var hasDocument: Bool {
        currentFileURL != nil && fileError == nil
    }

    /// 当前文档的大纲项
    var outlineItems: [OutlineItem] = []

    /// 大纲导航滚动请求（非 nil 时触发滚动，滚动后应清空）
    var scrollToLineRequest: Int?

    /// Per-file 内容缓存：保存未写入磁盘的编辑内容
    /// 切换文件时保存当前内容，切换回来时恢复缓存内容
    /// 确保 per-file UndoManager 的 undo 动作与内容一致
    private var contentCache: [URL: String] = [:]

    // MARK: - 依赖

    private let fileService: FileService

    /// 设置模型（用于读取默认显示模式等设置）
    var settings: SettingsModel

    // MARK: - 初始化

    init(fileService: FileService = FileService(), settings: SettingsModel = SettingsModel.shared) {
        self.fileService = fileService
        self.settings = settings
        self.displayMode = settings.defaultDisplayMode
    }

    // MARK: - 方法

    /// 加载文件内容
    /// - Parameter url: 文件 URL
    func loadFile(at url: URL) async {
        // 首次加载文件时应用默认显示模式
        if isFirstFile {
            displayMode = settings.defaultDisplayMode
            isFirstFile = false
        }

        // 切换文件前，保存当前文件的编辑内容到缓存
        // 确保 per-file UndoManager 的 undo 动作与内容一致
        if let currentURL = currentFileURL, currentURL != url, hasDocument {
            contentCache[currentURL] = content
        }

        // 检查是否为 Markdown 文件
        guard url.pathExtension == "md" else {
            fileError = .unsupportedFileType(url.pathExtension)
            content = ""
            currentFileURL = url
            fileName = url.lastPathComponent
            outlineItems = []
            return
        }

        isLoading = true
        fileError = nil

        do {
            let diskContent = try await fileService.readFile(at: url)
            currentFileURL = url
            fileName = url.lastPathComponent
            // 优先使用缓存内容（保留未保存的编辑）
            // 缓存内容与 per-file UndoManager 的 undo 动作一致
            if let cached = contentCache[url] {
                content = cached
            } else {
                content = diskContent
            }
            outlineItems = OutlineService.parse(content)
        } catch let fileError as FileError {
            self.fileError = fileError
            content = ""
            currentFileURL = url
            fileName = url.lastPathComponent
            outlineItems = []
        } catch {
            self.fileError = .unknown(error)
            content = ""
            currentFileURL = url
            fileName = url.lastPathComponent
            outlineItems = []
        }

        isLoading = false
    }

    /// 加载选中的文件节点
    /// - Parameter node: 文件节点
    func loadFileNode(_ node: FileNode) async {
        if !node.isMarkdown {
            fileError = .unsupportedFileType(node.path.pathExtension)
            currentFileURL = node.path
            fileName = node.name
            content = ""
            outlineItems = []
            return
        }
        await loadFile(at: node.path)
    }

    /// 切换显示模式
    func switchDisplayMode(_ mode: DisplayMode) {
        displayMode = mode
    }

    /// 请求滚动到指定行号（大纲导航使用）
    func requestScrollToLine(_ lineNumber: Int) {
        scrollToLineRequest = lineNumber
    }

    /// 清除滚动请求（滚动完成后调用）
    func clearScrollRequest() {
        scrollToLineRequest = nil
    }

    /// 清除当前文档
    func clearDocument() {
        content = ""
        currentFileURL = nil
        fileName = ""
        fileError = nil
        isLoading = false
        isFirstFile = true
        displayMode = settings.defaultDisplayMode
        outlineItems = []
        contentCache.removeAll()
    }
}
