import SwiftUI
import os

/// 应用委托，处理 macOS 应用生命周期事件
///
/// macOS 15+ 上 SwiftUI WindowGroup 在收到文件打开事件时可能创建不可见窗口。
/// 修复策略：
/// - 冷启动：SwiftUI 创建窗口（可能不可见），延迟后激活；文件通过 UserDefaults 传递给 ContentView.task
/// - 热启动有窗口：直接发送通知
/// - 热启动无窗口：激活 SwiftUI 创建的不可见窗口，然后发送通知
/// - Dock 点击无窗口：激活不可见窗口，重置为欢迎页
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let logger = Logger(subsystem: "com.markdownreader.app", category: "AppDelegate")

    /// 冷启动时记录待处理的文件 URL
    var pendingOpenFileURL: URL?

    /// 冷启动时记录待处理的目录 URL
    var pendingOpenDirectoryURL: URL?

    /// 应用是否已经完成启动（用于区分冷启动和热启动）
    private var didFinishLaunching = false

    /// 应用即将完成启动
    func applicationWillFinishLaunching(_ notification: Notification) {
        logger.info("applicationWillFinishLaunching")
    }

    // MARK: - 窗口辅助

    /// 激活第一个不可见的可成为 key 的窗口（SwiftUI WindowGroup 创建的）
    /// SwiftUI 有时会创建不可见窗口来处理文件打开事件，需要手动激活
    /// 使用 canBecomeKey + isSheet + isPanel 判断，避免依赖私有类名
    private func activateFirstHiddenWindow() {
        for window in NSApp.windows {
            if !window.isSheet && window.canBecomeKey && !(window is NSPanel) {
                if !window.isVisible || window.isMiniaturized {
                    logger.info("Activating hidden window: title='\(window.title)'")
                    window.deminiaturize(nil)
                    window.setIsVisible(true)
                    window.orderFrontRegardless()
                    window.makeKeyAndOrderFront(nil)
                }
                break
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    /// 检查是否有可见窗口
    private func hasVisibleWindows() -> Bool {
        NSApp.windows.contains { $0.isVisible && !$0.isSheet }
    }

    // MARK: - 文件打开回调

    /// macOS 13+ URL 版本的文件打开回调
    /// 冷启动时在 applicationDidFinishLaunching 之前调用
    /// 热启动时直接调用
    func application(_ application: NSApplication, open urls: [URL]) {
        logger.info("application(_:open:) called with \(urls.count) URLs")
        guard let url = urls.first else { return }

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

        // 存储到 UserDefaults，作为 ContentView.task 的后备读取路径
        if isDir.boolValue {
            pendingOpenDirectoryURL = url
            UserDefaults.standard.set(url.path as String, forKey: "pendingOpenDirectoryPath")
            UserDefaults.standard.removeObject(forKey: "pendingOpenFilePath")
        } else {
            pendingOpenFileURL = url
            UserDefaults.standard.set(url.path as String, forKey: "pendingOpenFilePath")
            UserDefaults.standard.removeObject(forKey: "pendingOpenDirectoryPath")
        }
        // 不需要手动 synchronize()，UserDefaults 会自动定期同步到磁盘

        if didFinishLaunching {
            // 热启动
            if hasVisibleWindows() {
                logger.info("Hot start: has visible window — posting notification")
                DispatchQueue.main.async {
                    let name: Notification.Name = isDir.boolValue ? .openDirectory : .openFile
                    NotificationCenter.default.post(name: name, object: url)
                }
            } else {
                // 无可见窗口：SwiftUI 可能创建了不可见窗口
                logger.info("Hot start: no visible window — activating hidden window + posting notification")
                activateFirstHiddenWindow()
                // 使用 async 而非 asyncAfter(0.3)，避免不必要的 300ms 延迟
                // activateFirstHiddenWindow 同步完成窗口激活，下一个 runloop 周期即可安全发通知
                DispatchQueue.main.async {
                    let name: Notification.Name = isDir.boolValue ? .openDirectory : .openFile
                    NotificationCenter.default.post(name: name, object: url)
                }
            }
        } else {
            logger.info("Cold start: stored pending URL")
        }
    }

    // MARK: - 应用生命周期

    /// 应用启动完成后，处理冷启动场景
    /// 如果有待处理文件 URL，ContentView.task 会通过 UserDefaults 读取并打开。
    /// 如果没有待处理文件且 reopenLastLocation 开启，发送 restoreLastLocation 通知。
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false

        // 在任何 SwiftUI 视图创建前设置 appearance，避免 NSTextView textColor 被 AppKit 覆盖
        // ContentView.task 中的 applyAppearance() 仍保留作为兜底
        let appearanceMode = SettingsModel.shared.appearanceMode
        if let nsAppearance = appearanceMode.nsAppearance {
            NSApp.appearance = nsAppearance
        }

        didFinishLaunching = true
        logger.info("applicationDidFinishLaunching — pendingFile: \(self.pendingOpenFileURL != nil), pendingDir: \(self.pendingOpenDirectoryURL != nil)")

        // 延迟处理，确保 SwiftUI WindowGroup 窗口已创建
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }

            // 如果没有可见窗口，激活 SwiftUI 创建的隐藏窗口
            if !self.hasVisibleWindows() {
                self.activateFirstHiddenWindow()
            }

            // 清理冷启动时的待处理 URL 属性
            // ContentView.task 已通过 UserDefaults 读取并处理，无需再发通知
            if self.pendingOpenFileURL != nil {
                self.pendingOpenFileURL = nil
                self.logger.info("Cold start: pending file handled by ContentView.task via UserDefaults")
            } else if self.pendingOpenDirectoryURL != nil {
                self.pendingOpenDirectoryURL = nil
                self.logger.info("Cold start: pending directory handled by ContentView.task via UserDefaults")
            } else if SettingsModel.shared.reopenLastLocation {
                self.logger.info("Cold start: restoring last location")
                NotificationCenter.default.post(name: .restoreLastLocation, object: nil)
            }
        }
    }

    // MARK: - Dock 点击处理

    /// 用户点击 Dock 图标时调用
    /// 当所有窗口都关闭后点击 Dock 图标，激活隐藏窗口
    /// 根据 reopenLastLocation 设置决定恢复上次位置还是显示欢迎页
    /// 返回 false 阻止 SwiftUI WindowGroup 自动创建新窗口，避免双窗口 bug
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            logger.info("applicationShouldHandleReopen — activating hidden window")
            activateFirstHiddenWindow()
            DispatchQueue.main.async { [weak self] in
                guard self != nil else { return }
                if SettingsModel.shared.reopenLastLocation {
                    // 恢复上次位置
                    NotificationCenter.default.post(name: .restoreLastLocation, object: nil)
                } else {
                    // 重置为欢迎页
                    NotificationCenter.default.post(name: .resetToWelcome, object: nil)
                }
            }
        }
        return false
    }
}
