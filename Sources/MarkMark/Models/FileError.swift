import Foundation

/// 文件错误类型
enum FileError: LocalizedError {
    case permissionDenied(URL)
    case encodingError(URL)
    case fileNotFound(URL)
    case unsupportedFileType(String)
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let url):
            "无法读取文件「\(url.lastPathComponent)」：权限不足"
        case .encodingError(let url):
            "无法读取文件「\(url.lastPathComponent)」：编码异常"
        case .fileNotFound(let url):
            "文件「\(url.lastPathComponent)」不存在"
        case .unsupportedFileType(let ext):
            "不支持预览该文件类型（.\(ext)）"
        case .unknown(let error):
            error.localizedDescription
        }
    }
}
