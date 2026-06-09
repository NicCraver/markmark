import Foundation

/// 文件系统服务，负责目录扫描和文件读取
struct FileService: Sendable {

    /// 已知的 Markdown 文件扩展名（不含 .txt，.txt 需内容检测）
    static let markdownExtensions: Set<String> = ["md", "markdown", "mdown", "mkd"]

    /// 需要在目录树中显示为 Markdown 类型的扩展名（含 .txt）
    /// .txt 文件在目录树中显示 Markdown 图标，实际加载时再做内容检测
    static let treeDisplayExtensions: Set<String> = ["md", "markdown", "mdown", "mkd", "txt"]

    /// 判断文件扩展名是否为已知的 Markdown 类型（不含 .txt）
    /// - Parameter url: 文件 URL
    /// - Returns: 是否为 Markdown 扩展名
    static func isKnownMarkdownExtension(_ url: URL) -> Bool {
        markdownExtensions.contains(url.pathExtension.lowercased())
    }

    /// 判断文件扩展名是否应在目录树中显示为 Markdown 类型（含 .txt）
    /// - Parameter url: 文件 URL
    /// - Returns: 是否为 Markdown 或潜在 Markdown 扩展名
    static func isTreeDisplayExtension(_ url: URL) -> Bool {
        treeDisplayExtensions.contains(url.pathExtension.lowercased())
    }

    /// 判断文件是否为 Markdown 文件
    /// 对于 .md/.markdown/.mdown/.mkd 直接返回 true
    /// 对于 .txt 需要读取内容进行语法特征检测
    /// - Parameters:
    ///   - url: 文件 URL
    ///   - content: 可选的文件内容（传入则避免重复读取）
    /// - Returns: 是否为 Markdown 文件
    static func isMarkdownFile(_ url: URL, content: String? = nil) -> Bool {
        let ext = url.pathExtension.lowercased()
        if markdownExtensions.contains(ext) {
            return true
        }
        if ext == "txt" {
            // .txt 文件需要内容检测
            if let content = content {
                return detectMarkdownContent(content)
            } else if let data = try? Data(contentsOf: url),
                      let text = String(data: data, encoding: .utf8) {
                return detectMarkdownContent(text)
            }
            return false
        }
        return false
    }

    /// 通过内容特征检测文本是否为 Markdown
    /// 检测常见 Markdown 语法元素，命中阈值即判定为 Markdown
    /// - Parameter content: 文件内容
    /// - Returns: 是否包含足够的 Markdown 特征
    static func detectMarkdownContent(_ content: String) -> Bool {
        // 空文件不判定为 Markdown
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        var score = 0

        // ATX 标题: # ## ### 等
        if content.range(of: #"^#{1,6}\s+\S"#, options: .regularExpression) != nil {
            score += 2
        }

        // Setext 标题: 下一行是 === 或 ---
        if content.range(of: #"\n[=-]{3,}\s*\n"#, options: .regularExpression) != nil {
            score += 2
        }

        // 代码围栏: ``` 或 ~~~
        if content.range(of: #"(^|\n)`{3}|~{3}"#, options: .regularExpression) != nil {
            score += 2
        }

        // 强调/加粗: **text** 或 __text__
        if content.range(of: #"\*\*[^*]+\*\*|__[^_]+__"#, options: .regularExpression) != nil {
            score += 1
        }

        // 链接: [text](url)
        if content.range(of: #"\[[^\]]+\]\([^)]+\)"#, options: .regularExpression) != nil {
            score += 1
        }

        // 图片: ![alt](url)
        if content.range(of: #"!\[[^\]]*\]\([^)]+\)"#, options: .regularExpression) != nil {
            score += 1
        }

        // 列表: - item 或 * item 或 1. item
        if content.range(of: #"^\s*[-*]\s+\S"#, options: .regularExpression) != nil {
            score += 1
        }
        if content.range(of: #"^\s*\d+\.\s+\S"#, options: .regularExpression) != nil {
            score += 1
        }

        // 引用: > text
        if content.range(of: #"^\s*>\s+\S"#, options: .regularExpression) != nil {
            score += 1
        }

        // 阈值: 2 分以上判定为 Markdown
        return score >= 2
    }

    /// 扫描指定目录，返回文件树结构
    /// - Parameters:
    ///   - directory: 要扫描的目录 URL
    ///   - showHiddenFiles: 是否显示隐藏文件
    ///   - showNonMarkdownFiles: 是否显示非 Markdown 文件
    /// - Returns: 排序后的 FileNode 数组
    func scanDirectory(
        _ directory: URL,
        showHiddenFiles: Bool = false,
        showNonMarkdownFiles: Bool = true
    ) async throws -> [FileNode] {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants]
        if !showHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey, .nameKey],
            options: options
        )

        var nodes: [FileNode] = []

        for url in contents {
            let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey, .nameKey])
            let isDirectory = resourceValues.isDirectory ?? false
            let name = resourceValues.name ?? url.lastPathComponent
            let isTreeMarkdown = Self.isTreeDisplayExtension(url)

            if isDirectory {
                let children = try await scanDirectory(
                    url,
                    showHiddenFiles: showHiddenFiles,
                    showNonMarkdownFiles: showNonMarkdownFiles
                )
                // 空目录也显示（children 为空数组），以便用户新建空目录后能立即看到
                let node = FileNode(
                    name: name,
                    path: url,
                    isDirectory: true,
                    children: children
                )
                nodes.append(node)
            } else {
                // 如果不显示非 Markdown 文件，则跳过
                if !showNonMarkdownFiles && !isTreeMarkdown { continue }
                let node = FileNode(
                    name: name,
                    path: url,
                    isDirectory: false,
                    isMarkdown: isTreeMarkdown,
                    children: nil
                )
                nodes.append(node)
            }
        }

        // 排序：目录在前，文件在后；同类型按名称排序
        nodes.sort { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        return nodes
    }

    /// 读取文件内容
    /// - Parameter url: 文件 URL
    /// - Returns: 文件内容字符串
    func readFile(at url: URL) async throws -> String {
        do {
            // 检查文件是否可读
            if FileManager.default.isReadableFile(atPath: url.path) == false {
                throw FileError.permissionDenied(url)
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            return content
        } catch let error as FileError {
            throw error
        } catch {
            // 尝试用其他编码读取
            if let content = try? String(contentsOf: url, encoding: .ascii) {
                return content
            }
            throw FileError.encodingError(url)
        }
    }

    /// 写入文件内容
    /// - Parameters:
    ///   - url: 文件 URL
    ///   - content: 要写入的内容
    func writeFile(at url: URL, content: String) async throws {
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            throw FileError.permissionDenied(url)
        }
    }

    /// 检查目录是否包含 Markdown 文件
    /// - Parameters:
    ///   - directory: 要检查的目录
    ///   - showHiddenFiles: 是否检查隐藏文件
    /// - Returns: 是否包含 .md 文件
    func directoryContainsMarkdown(_ directory: URL, showHiddenFiles: Bool = false) -> Bool {
        var options: FileManager.DirectoryEnumerationOptions = []
        if !showHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: options
        ) else {
            return false
        }

        for case let url as URL in enumerator {
            if Self.isKnownMarkdownExtension(url) {
                return true
            }
        }
        return false
    }

    /// 重命名文件或目录
    /// - Parameters:
    ///   - url: 原始 URL
    ///   - newName: 新名称（仅文件名，不含路径）
    /// - Returns: 重命名后的新 URL
    func renameItem(at url: URL, to newName: String) throws -> URL {
        let newURL = url.deletingLastPathComponent().appendingPathComponent(newName)
        try FileManager.default.moveItem(at: url, to: newURL)
        return newURL
    }

    /// 将文件或目录移到废纸篓
    /// - Parameter url: 要删除的文件/目录 URL
    func trashItem(at url: URL) throws {
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    /// 创建子目录
    /// - Parameters:
    ///   - parentDirectory: 父目录 URL
    ///   - name: 子目录名称
    /// - Returns: 新建目录的 URL
    @discardableResult
    func createDirectory(in parentDirectory: URL, name: String) throws -> URL {
        let newURL = parentDirectory.appendingPathComponent(name)
        try FileManager.default.createDirectory(at: newURL, withIntermediateDirectories: false)
        return newURL
    }

    /// 移动文件或目录到目标目录
    /// - Parameters:
    ///   - source: 源 URL
    ///   - destination: 目标目录 URL
    /// - Returns: 移动后的新 URL
    func moveItem(at source: URL, to destination: URL) throws -> URL {
        let newURL = destination.appendingPathComponent(source.lastPathComponent)
        try FileManager.default.moveItem(at: source, to: newURL)
        return newURL
    }
}
