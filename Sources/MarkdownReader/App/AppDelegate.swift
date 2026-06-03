import SwiftUI

/// 应用委托，处理 macOS 应用生命周期事件
/// 负责捕获冷启动时的文件打开事件，热启动时与 .onOpenURL 配合
/// 使用 lastHandledURL 去重，防止 AppDelegate 和 .onOpenURL 同时触发导致重复打开
final class AppDelegate: NSObject, NSApplicationDelegate {

    /// 冷启动时通过文件打开应用，记录待处理的文件 URL
    /// 供 ContentView 的 .task 读取以跳过 restoreLastLocation()
    private(set) var pendingOpenFileURL: URL?

    /// 应用是否已经完成启动（用于区分冷启动和热启动）
    private var didFinishLaunching = false

    /// 记录最近由 AppDelegate 处理的 URL，用于 .onOpenURL 去重
    /// 当 AppDelegate 和 .onOpenURL 同时触发时，避免重复处理同一文件
    private var lastHandledURL: URL?

    /// 应用启动完成后发送待处理的文件打开通知
    /// 冷启动时：application(_:openFiles:) 一定已在之前调用，pendingOpenFileURL 已设置
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 禁用窗口标签页功能，隐藏「显示标签页栏」和「显示所有标签页」菜单项
        NSWindow.allowsAutomaticWindowTabbing = false

        didFinishLaunching = true
        if let url = pendingOpenFileURL {
            lastHandledURL = url
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .openFile, object: url)
            }
        }
    }

    /// 处理通过 Finder 双击或右键「打开方式」打开的文件
    /// 冷启动：记录 URL，等 applicationDidFinishLaunching 发通知
    /// 热启动：直接发送通知，同时记录 lastHandledURL 供 .onOpenURL 去重
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let path = filenames.first else {
            NSApp.reply(toOpenOrPrint: .success)
            return
        }

        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        lastHandledURL = url
        if isDir.boolValue {
            pendingOpenFileURL = nil
            if didFinishLaunching {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .openDirectory, object: url)
                }
            }
        } else {
            pendingOpenFileURL = url
            if didFinishLaunching {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .openFile, object: url)
                }
            }
        }

        NSApp.reply(toOpenOrPrint: .success)
    }

    /// 应用通过 URL Scheme 打开时调用
    /// 热启动时直接发送通知，同时记录 lastHandledURL 供 .onOpenURL 去重
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        lastHandledURL = url
        if isDir.boolValue {
            pendingOpenFileURL = nil
            if didFinishLaunching {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .openDirectory, object: url)
                }
            }
        } else {
            pendingOpenFileURL = url
            if didFinishLaunching {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .openFile, object: url)
                }
            }
        }
    }

    /// 检查 URL 是否已被 AppDelegate 处理
    /// 用于 .onOpenURL 去重：如果 AppDelegate 已处理，则 .onOpenURL 跳过
    /// 调用后清除 lastHandledURL，确保下次不同 URL 能正常处理
    func isURLAlreadyHandled(_ url: URL) -> Bool {
        if lastHandledURL == url {
            lastHandledURL = nil
            return true
        }
        return false
    }
}
