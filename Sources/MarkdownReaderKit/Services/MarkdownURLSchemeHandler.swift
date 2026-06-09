import Foundation
import WebKit

/// `mr://` 自定义 scheme 处理器（WKWebView 版本）。
///
/// v2.x 早期使用 SwiftUI WebKit 的 `URLSchemeHandler`（仅 macOS 26+）。
/// 为支持 macOS 15，迁移回经典 `WKURLSchemeHandler`，逻辑保持一致：
/// 将 `mr:///<path>` 解析为磁盘上的资源文件并返回。
public final class MarkdownURLSchemeHandler: NSObject, WKURLSchemeHandler {
    private let baseURL: URL?
    private let resourceSearchPaths: [URL]?

    public init(baseURL: URL?, resourceSearchPaths: [URL]? = nil) {
        self.baseURL = baseURL
        self.resourceSearchPaths = resourceSearchPaths
        super.init()
    }

    public func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, url.scheme == "mr" else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        var path = url.path
        if path.hasPrefix("/") {
            path = String(path.dropFirst())
        }

        let resourceURL = Self.resolveResourceURL(
            path: path,
            baseURL: baseURL,
            resourceSearchPaths: resourceSearchPaths
        )

        guard let resourceURL, FileManager.default.fileExists(atPath: resourceURL.path) else {
            let response = HTTPURLResponse(
                url: url,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didFinish()
            return
        }

        do {
            let data = try Data(contentsOf: resourceURL)
            let mimeType = Self.mimeType(for: resourceURL.pathExtension)
            let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": mimeType]
            )!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    public func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    static func resolveResourceURL(path: String, baseURL: URL?, resourceSearchPaths: [URL]?) -> URL? {
        let absoluteURL = URL(fileURLWithPath: "/" + path)
        if FileManager.default.fileExists(atPath: absoluteURL.path) {
            return absoluteURL
        }

        if let baseURL, FileManager.default.fileExists(atPath: baseURL.appendingPathComponent(path).path) {
            return baseURL.appendingPathComponent(path)
        }

        var searchPaths: [URL] = []

        if let customPaths = resourceSearchPaths {
            searchPaths = customPaths.map { $0.appendingPathComponent(path) }
        } else {
            searchPaths = [
                Bundle.main.resourceURL?.appendingPathComponent("MarkMark_MarkMark.bundle").appendingPathComponent("Resources").appendingPathComponent(path),
                Bundle.main.resourceURL?.appendingPathComponent("Resources").appendingPathComponent(path),
                Bundle.main.resourceURL?.appendingPathComponent(path),
            ].compactMap { $0 }
        }

        for url in searchPaths where FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        return nil
    }

    static func mimeType(for pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "html", "htm": return "text/html"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "ico": return "image/x-icon"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "ttf": return "font/ttf"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }
}
