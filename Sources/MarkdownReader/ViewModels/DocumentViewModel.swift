import SwiftUI

/// 文档视图模型，管理当前文档状态和文件读取
@MainActor
@Observable
final class DocumentViewModel {

    // MARK: - 状态

    /// 当前文档内容
    var content: String = "" {
        didSet {
            // 内容变更时标记为脏（跳过首次加载时的赋值）
            if currentFileURL != nil && !isLoading {
                markDirtyIfNeeded()
            }
        }
    }

    /// 当前文件 URL
    var currentFileURL: URL? {
        didSet { syncHasDocument() }
    }

    /// 当前文件名
    var fileName: String = ""

    /// 显示模式
    var displayMode: DisplayMode = .rendered

    /// 是否正在加载
    var isLoading: Bool = false

    /// 错误信息
    var fileError: FileError? {
        didSet { syncHasDocument() }
    }

    /// 内容是否有未保存的修改
    var isDirty: Bool = false

    /// 当前文件是否为未保存的新建文件（位于临时目录）
    var isUntitled: Bool = false

    var hasDocument: Bool = false

    /// 文件是否被外部编辑器修改
    var isFileModifiedExternally: Bool = false

    /// 是否正在保存（用于忽略自己保存触发的文件系统事件）
    private var isSaving: Bool = false

    /// 新建文件的临时目录
    static let untitledDirectory: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MarkdownReader")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// 是否有任何未保存的文件（包括当前文件和缓存中的文件）
    var hasAnyDirtyFile: Bool {
        if isDirty { return true }
        for (url, content) in contentCache {
            if let snapshot = diskContentSnapshot[url], content != snapshot {
                return true
            }
        }
        return false
    }

    /// 当前文档的大纲项
    var outlineItems: [OutlineItem] = []

    /// 大纲导航滚动请求（非 nil 时触发滚动，滚动后应清空）
    var scrollToLineRequest: Int?

    /// 当前光标所在行号（1-based），Raw 模式下由编辑器实时更新
    /// 与 HTML data-line 属性和 OutlineItem.lineNumber 使用相同约定
    var cursorLineNumber: Int = 1

    /// Per-file 内容缓存：保存未写入磁盘的编辑内容
    /// 切换文件时保存当前内容，切换回来时恢复缓存内容
    /// 确保 per-file UndoManager 的 undo 动作与内容一致
    private var contentCache: [URL: String] = [:]

    /// Per-file 显示模式缓存：每个文件记住自己的显示模式
    /// 切换文件时保存当前模式，切换回来时恢复，避免模式全局串扰
    private var displayModeCache: [URL: DisplayMode] = [:]

    /// Per-file 磁盘内容快照，用于判断内容是否已修改
    private var diskContentSnapshot: [URL: String] = [:]

    /// 当前打开文件的文件系统监控器
    private let fileWatcher = FileSystemWatcher(debounceInterval: 0.5)

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
        // 幂等保护：如果已经加载了同一文件且内容非空，跳过重复加载
        if currentFileURL == url && !content.isEmpty && fileError == nil {
            return
        }

        // 切换文件前，保存当前文件的编辑内容和显示模式到缓存
        if let currentURL = currentFileURL, currentURL != url, hasDocument {
            contentCache[currentURL] = content
            displayModeCache[currentURL] = displayMode
        }

        if isUntitled, let oldURL = currentFileURL, oldURL != url {
            try? FileManager.default.removeItem(at: oldURL)
            contentCache.removeValue(forKey: oldURL)
            diskContentSnapshot.removeValue(forKey: oldURL)
        }

        // 检查是否为 Markdown 文件
        guard url.pathExtension == "md" else {
            fileError = .unsupportedFileType(url.pathExtension)
            content = ""
            currentFileURL = url
            fileName = url.lastPathComponent
            outlineItems = []
            isDirty = false
            isUntitled = false
            return
        }

        isLoading = true
        fileError = nil

        do {
            let diskContent = try await fileService.readFile(at: url)
            currentFileURL = url
            fileName = url.lastPathComponent
            // 保存磁盘内容快照，用于脏状态判断
            diskContentSnapshot[url] = diskContent
            // 优先使用缓存内容（保留未保存的编辑）
            // 缓存内容与 per-file UndoManager 的 undo 动作一致
            if let cached = contentCache[url] {
                content = cached
            } else {
                content = diskContent
            }
            // 更新脏状态
            isDirty = (content != diskContent)
            // 加载真实文件时重置 isUntitled
            isUntitled = false
            outlineItems = OutlineService.parse(content)
            // 恢复目标文件的显示模式（有缓存用缓存，否则用默认设置）
            displayMode = displayModeCache[url] ?? settings.defaultDisplayMode
        } catch let fileError as FileError {
            self.fileError = fileError
            content = ""
            currentFileURL = url
            fileName = url.lastPathComponent
            outlineItems = []
            isDirty = false
            isUntitled = false
        } catch {
            self.fileError = .unknown(error)
            content = ""
            currentFileURL = url
            fileName = url.lastPathComponent
            outlineItems = []
            isDirty = false
            isUntitled = false
        }

        isLoading = false

        // 启动文件监控（排除临时文件）
        startFileWatcher(for: url)
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
            isUntitled = false
            return
        }
        await loadFile(at: node.path)
    }

    /// 切换显示模式
    func switchDisplayMode(_ mode: DisplayMode) {
        let previousMode = displayMode
        displayMode = mode
        // 同步更新缓存，确保切换文件后能恢复正确的模式
        if let url = currentFileURL {
            displayModeCache[url] = mode
        }
        // 从 Raw 切到 Rendered 时，同步光标位置到渲染视图
        if previousMode == .raw && mode == .rendered {
            requestScrollToLine(cursorLineNumber)
        }
    }

    /// 请求滚动到指定行号（大纲导航使用）
    func requestScrollToLine(_ lineNumber: Int) {
        scrollToLineRequest = lineNumber
    }

    /// 清除滚动请求（滚动完成后调用）
    func clearScrollRequest() {
        scrollToLineRequest = nil
    }

    @discardableResult
    func createUntitledFile() -> URL? {
        if isUntitled { return nil }

        // 切换前保存当前文件的编辑内容和显示模式
        if let currentURL = currentFileURL, hasDocument {
            contentCache[currentURL] = content
            displayModeCache[currentURL] = displayMode
        }

        let tempDir = Self.untitledDirectory
        let untitledName = "Untitled.md"
        let fileURL = tempDir.appendingPathComponent(untitledName)

        // 创建空文件
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)

        // 使用 isLoading 阻止 content 的 didSet 触发 markDirtyIfNeeded()
        // 确保所有属性一次性设置完毕后再通知 SwiftUI
        isLoading = true

        currentFileURL = fileURL
        fileName = untitledName
        // 先设置快照，再设置 content，确保 markDirtyIfNeeded 即使被调用也能正确比较
        diskContentSnapshot[fileURL] = ""
        contentCache[fileURL] = ""
        content = ""
        outlineItems = []
        isDirty = false
        isUntitled = true
        fileError = nil
        displayMode = .raw  // 新建文件始终使用 Raw 模式，便于立即开始编辑

        isLoading = false

        return fileURL
    }

    /// 保存当前文档内容到磁盘
    /// 如果是未保存的新建文件，返回 false 并发送 .saveAsFile 通知
    /// - Returns: 是否保存成功
    @discardableResult
    func save() async -> Bool {
        guard let url = currentFileURL else { return false }

        // 未保存的新建文件需要另存为
        if isUntitled {
            NotificationCenter.default.post(name: .saveAsFile, object: nil)
            return false
        }

        isSaving = true
        defer { isSaving = false }

        do {
            try await fileService.writeFile(at: url, content: content)
            // 更新磁盘快照
            diskContentSnapshot[url] = content
            isDirty = false
            isFileModifiedExternally = false
            // 同步更新缓存
            contentCache[url] = content
            return true
        } catch {
            fileError = .permissionDenied(url)
            return false
        }
    }

    /// 另存为：将内容保存到用户指定的新位置
    /// - Parameter newURL: 用户选择的新保存位置
    func saveAs(to newURL: URL) async {
        do {
            let oldURL = currentFileURL
            try await fileService.writeFile(at: newURL, content: content)

            // 清理旧的临时文件
            if isUntitled, let old = oldURL {
                try? FileManager.default.removeItem(at: old)
                contentCache.removeValue(forKey: old)
                diskContentSnapshot.removeValue(forKey: old)
            }

            // 更新文件引用
            currentFileURL = newURL
            fileName = newURL.lastPathComponent
            diskContentSnapshot[newURL] = content
            contentCache[newURL] = content
            isDirty = false
            isUntitled = false
            fileError = nil
            // 启动对新保存文件的外部变更监控
            startFileWatcher(for: newURL)
        } catch {
            fileError = .permissionDenied(newURL)
        }
    }

    /// 检查内容是否与磁盘快照不同，更新脏状态
    private func markDirtyIfNeeded() {
        guard let url = currentFileURL else {
            isDirty = false
            return
        }
        if let snapshot = diskContentSnapshot[url] {
            isDirty = (content != snapshot)
        }
    }

    /// 同步 hasDocument 存储属性，确保 @Observable 可靠追踪
    /// 在 currentFileURL / fileError 的 didSet 中自动调用
    private func syncHasDocument() {
        hasDocument = (currentFileURL != nil && fileError == nil)
    }

    /// 检查指定文件是否有未保存的修改
    /// 比较缓存内容（或当前内容）与磁盘快照，判断文件是否处于脏状态
    /// - Parameter url: 文件 URL
    /// - Returns: 是否有未保存的修改
    func isFileDirty(at url: URL) -> Bool {
        // 当前正在编辑的文件，直接使用 isDirty
        if url == currentFileURL {
            return isDirty
        }
        // 非当前文件，比较缓存内容与磁盘快照
        guard let cached = contentCache[url], let snapshot = diskContentSnapshot[url] else {
            return false
        }
        return cached != snapshot
    }

    /// 清除当前文档
    func clearDocument() {
        // 清理未保存新建文件的临时文件
        if isUntitled, let url = currentFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        stopFileWatcher()
        content = ""
        currentFileURL = nil
        fileName = ""
        fileError = nil
        isLoading = false
        isDirty = false
        isUntitled = false
        isFileModifiedExternally = false
        displayMode = settings.defaultDisplayMode
        outlineItems = []
        contentCache.removeAll()
        displayModeCache.removeAll()
        diskContentSnapshot.removeAll()
    }

    /// 取消选中当前文件（保留其他文件的缓存）
    /// 用于外部删除等场景：仅清理当前文件状态，不丢失其他已编辑文件的缓存
    func deselectCurrentFile() {
        stopFileWatcher()
        if let url = currentFileURL {
            contentCache.removeValue(forKey: url)
            displayModeCache.removeValue(forKey: url)
            diskContentSnapshot.removeValue(forKey: url)
        }
        content = ""
        currentFileURL = nil
        fileName = ""
        fileError = nil
        isLoading = false
        isDirty = false
        isUntitled = false
        isFileModifiedExternally = false
        displayMode = settings.defaultDisplayMode
        outlineItems = []
    }

    func discardUntitledFile() {
        guard isUntitled, let url = currentFileURL else { return }
        stopFileWatcher()
        try? FileManager.default.removeItem(at: url)
        contentCache.removeValue(forKey: url)
        diskContentSnapshot.removeValue(forKey: url)
        isUntitled = false
        isDirty = false
        isFileModifiedExternally = false
    }

    // MARK: - 文件监控与外部变更检测

    /// 启动对指定文件的外部变更监控
    /// - Parameter url: 要监控的文件 URL
    private func startFileWatcher(for url: URL) {
        // 不监控临时文件
        guard !url.path.hasPrefix(Self.untitledDirectory.path) else {
            fileWatcher.stopWatching()
            return
        }

        // 监控文件所在目录（FSEventStream 不支持直接监控单个文件）
        let directory = url.deletingLastPathComponent()
        fileWatcher.startWatching(url: directory) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.checkExternalFileChange()
            }
        }
    }

    /// 停止文件监控
    private func stopFileWatcher() {
        fileWatcher.stopWatching()
    }

    /// 检查当前文件是否被外部修改
    private func checkExternalFileChange() async {
        guard let url = currentFileURL,
              !isUntitled,
              !isSaving,
              !url.path.hasPrefix(Self.untitledDirectory.path) else { return }

        do {
            let diskContent = try await fileService.readFile(at: url)
            // 与当前快照比较，若不同则处理外部修改
            if let snapshot = diskContentSnapshot[url], diskContent != snapshot {
                if !isDirty {
                    // 用户未修改过，自动静默刷新
                    content = diskContent
                    diskContentSnapshot[url] = diskContent
                    contentCache[url] = diskContent
                    outlineItems = OutlineService.parse(diskContent)
                } else {
                    // 用户有修改，显示刷新按钮
                    isFileModifiedExternally = true
                }
            }
        } catch {
            // 文件可能已被删除，忽略错误
        }
    }

    /// 从磁盘重新加载当前文件（丢弃当前修改）
    func reloadFromDisk() async {
        guard let url = currentFileURL else { return }

        isLoading = true
        isFileModifiedExternally = false

        do {
            let diskContent = try await fileService.readFile(at: url)
            content = diskContent
            diskContentSnapshot[url] = diskContent
            contentCache[url] = diskContent
            isDirty = false
            outlineItems = OutlineService.parse(diskContent)
        } catch {
            fileError = .unknown(error)
        }

        isLoading = false
    }

    // MARK: - 文件系统操作协调

    /// 处理文件被重命名的场景，更新内部缓存和当前文件引用
    /// - Parameters:
    ///   - oldURL: 重命名前的 URL
    ///   - newURL: 重命名后的 URL
    func handleFileRenamed(from oldURL: URL, to newURL: URL) {
        // 迁移缓存
        if let cached = contentCache[oldURL] {
            contentCache.removeValue(forKey: oldURL)
            contentCache[newURL] = cached
        }
        if let snapshot = diskContentSnapshot[oldURL] {
            diskContentSnapshot.removeValue(forKey: oldURL)
            diskContentSnapshot[newURL] = snapshot
        }
        if let mode = displayModeCache[oldURL] {
            displayModeCache.removeValue(forKey: oldURL)
            displayModeCache[newURL] = mode
        }

        // 更新当前编辑的文件引用
        if currentFileURL == oldURL {
            currentFileURL = newURL
            fileName = newURL.lastPathComponent
            // 同一目录重命名，目录监控仍有效，但重启以确保路径一致性
            startFileWatcher(for: newURL)
        }
    }

    /// 处理文件被删除的场景，清理编辑状态
    /// - Parameter url: 被删除文件的 URL
    func handleFileDeleted(at url: URL) {
        // 清理缓存
        contentCache.removeValue(forKey: url)
        diskContentSnapshot.removeValue(forKey: url)
        displayModeCache.removeValue(forKey: url)

        // 如果当前正在编辑被删除的文件，先保存再清理
        if currentFileURL == url {
            if isDirty {
                // 有未保存修改：另存为临时文件保留内容
                let tempURL = Self.untitledDirectory.appendingPathComponent(fileName)
                try? content.write(to: tempURL, atomically: true, encoding: .utf8)
                currentFileURL = tempURL
                isUntitled = true
                diskContentSnapshot[tempURL] = content
                contentCache[tempURL] = content
            } else {
                // 无未保存修改：直接清理
                deselectCurrentFile()
            }
        }
    }

    /// 处理文件被移动的场景，更新内部缓存和当前文件引用
    /// - Parameters:
    ///   - oldURL: 移动前的 URL
    ///   - newURL: 移动后的 URL
    func handleFileMoved(from oldURL: URL, to newURL: URL) {
        // 迁移缓存（与重命名逻辑一致）
        if let cached = contentCache[oldURL] {
            contentCache.removeValue(forKey: oldURL)
            contentCache[newURL] = cached
        }
        if let snapshot = diskContentSnapshot[oldURL] {
            diskContentSnapshot.removeValue(forKey: oldURL)
            diskContentSnapshot[newURL] = snapshot
        }
        if let mode = displayModeCache[oldURL] {
            displayModeCache.removeValue(forKey: oldURL)
            displayModeCache[newURL] = mode
        }

        // 更新当前编辑的文件引用
        if currentFileURL == oldURL {
            currentFileURL = newURL
            fileName = newURL.lastPathComponent
            startFileWatcher(for: newURL)
        }

        // 如果当前编辑的文件在被移动的目录内，也更新引用
        if let current = currentFileURL, current.path.hasPrefix(oldURL.path + "/") {
            let relativePath = current.path.replacingOccurrences(of: oldURL.path, with: newURL.path)
            let newCurrentURL = URL(fileURLWithPath: relativePath)
            currentFileURL = newCurrentURL
            fileName = newCurrentURL.lastPathComponent
            startFileWatcher(for: newCurrentURL)
        }

        // 迁移目录内所有子文件的缓存
        let keysToMigrate = contentCache.keys.filter { $0.path.hasPrefix(oldURL.path + "/") }
        for key in keysToMigrate {
            let relativePath = key.path.replacingOccurrences(of: oldURL.path, with: newURL.path)
            let newKey = URL(fileURLWithPath: relativePath)
            contentCache[newKey] = contentCache.removeValue(forKey: key)
        }
        let snapshotKeysToMigrate = diskContentSnapshot.keys.filter { $0.path.hasPrefix(oldURL.path + "/") }
        for key in snapshotKeysToMigrate {
            let relativePath = key.path.replacingOccurrences(of: oldURL.path, with: newURL.path)
            let newKey = URL(fileURLWithPath: relativePath)
            diskContentSnapshot[newKey] = diskContentSnapshot.removeValue(forKey: key)
        }
        let modeKeysToMigrate = displayModeCache.keys.filter { $0.path.hasPrefix(oldURL.path + "/") }
        for key in modeKeysToMigrate {
            let relativePath = key.path.replacingOccurrences(of: oldURL.path, with: newURL.path)
            let newKey = URL(fileURLWithPath: relativePath)
            displayModeCache[newKey] = displayModeCache.removeValue(forKey: key)
        }
    }
}
