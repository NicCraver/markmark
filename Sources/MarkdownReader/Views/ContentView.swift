import SwiftUI

/// 主视图，管理自定义 HStack 两列布局
/// 设置模式下左侧显示设置菜单，右侧显示设置内容
struct ContentView: View {
    @State private var appViewModel = AppViewModel()
    @State private var fileTreeViewModel = FileTreeViewModel()
    @State private var documentViewModel = DocumentViewModel()
    @State private var settings = SettingsModel.shared
    @Environment(\.language) private var language
    @Environment(\.colorScheme) private var colorScheme

    /// 缓存的主题颜色，避免每次 body 求值时重复执行 NSColor 色彩空间转换和混合运算
    /// 通过 .onChange(of: settings.resolvedTheme) 响应式更新
    @State private var themeColors: ThemeColors = ThemeColors.from(
        SettingsModel.shared.resolvedTheme
    )

    var body: some View {
        mainLayout
            .frame(minWidth: 650, minHeight: 450)
            .ignoresSafeArea()
            .background(themeColors.surface)
            .navigationTitle(appViewModel.windowTitle)
            .environment(\.language, settings.languagePref.resolvedLanguage)
            .applyThemeColors(themeColors)
            .tint(themeColors.accent)
            .modifier(FullScreenStateModifier(appViewModel: appViewModel))
            .modifier(KeyboardShortcutModifier(
                appViewModel: appViewModel,
                documentViewModel: documentViewModel
            ))
            .modifier(FileOpenModifier(
                appViewModel: appViewModel,
                documentViewModel: documentViewModel,
                fileTreeViewModel: fileTreeViewModel,
                settings: settings
            ))
            .modifier(DirectoryChangeModifier(
                appViewModel: appViewModel,
                documentViewModel: documentViewModel,
                fileTreeViewModel: fileTreeViewModel
            ))
            .modifier(SelectionChangeModifier(
                appViewModel: appViewModel,
                documentViewModel: documentViewModel,
                fileTreeViewModel: fileTreeViewModel
            ))
            .modifier(SettingsChangeModifier(
                appViewModel: appViewModel,
                fileTreeViewModel: fileTreeViewModel,
                settings: settings
            ))
            .modifier(ToggleSettingsModifier(appViewModel: appViewModel))
            .background(TrafficLightHider(bgColor: themeColors.bgSubtle))
            .task {
                applyAppearance(settings.appearanceMode)
                if settings.reopenLastLocation {
                    restoreLastLocation()
                }
            }
            .onChange(of: colorScheme) { _, newScheme in
                // 仅在「跟随系统」模式下更新 systemIsDark
                // 避免手动选择浅色/深色时，colorScheme 变化污染 systemIsDark
                if settings.appearanceMode == .system {
                    settings.systemIsDark = (newScheme == .dark)
                }
            }
            .onChange(of: settings.appearanceMode) { _, newMode in
                // 切换到「跟随系统」时，立即刷新 systemIsDark 为当前系统外观
                if newMode == .system {
                    settings.systemIsDark = NSApp.effectiveAppearance
                        .bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                }
            }
            // 主题变化时重新计算缓存的主题颜色
            // resolvedTheme 是 Equatable，仅在主题实际变更时触发
            .onChange(of: settings.resolvedTheme) { _, newTheme in
                themeColors = ThemeColors.from(newTheme)
            }
    }

    // MARK: - 布局

    private var mainLayout: some View {
        HStack(spacing: 0) {
            if appViewModel.isShowingSettings {
                // 设置模式：左侧设置菜单
                SettingsSidebarView(appViewModel: appViewModel)
                    .frame(width: appViewModel.sidebarWidth)

                ResizeHandle(appViewModel: appViewModel)
                    .background(themeColors.bgSubtle)

                // 右侧设置内容
                SettingsContentView(appViewModel: appViewModel, settings: settings)
            } else {
                // 正常模式：文件树 + 文档
                if appViewModel.isSidebarVisible {
                    SidebarView(
                        fileTreeViewModel: fileTreeViewModel,
                        appViewModel: appViewModel
                    )
                    .frame(width: appViewModel.sidebarWidth)

                    ResizeHandle(appViewModel: appViewModel)
                        .background(themeColors.bgSubtle)
                }

                DetailView(
                    appViewModel: appViewModel,
                    documentViewModel: documentViewModel,
                    fileTreeViewModel: fileTreeViewModel,
                    settings: settings
                )
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appViewModel.isShowingSettings)
    }

    // MARK: - 方法

    private func applyAppearance(_ mode: AppearanceMode) {
        NSApp.appearance = mode.nsAppearance
    }

    private func restoreLastLocation() {
        if let dir = settings.lastOpenedDirectory {
            appViewModel.openDirectory(dir)
        } else if let file = settings.lastOpenedFile {
            appViewModel.openSingleFile(file)
            fileTreeViewModel.selectedFileURL = file
            Task {
                await documentViewModel.loadFile(at: file)
            }
        } else {
            let homeDir = URL(fileURLWithPath: NSHomeDirectory())
            appViewModel.openDirectory(homeDir)
        }
    }
}

// MARK: - 设置侧边栏

/// 设置模式下的左侧菜单视图
struct SettingsSidebarView: View {
    let appViewModel: AppViewModel
    @Environment(\.language) private var language
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 顶部区域：自定义红绿灯（50px）
            HStack(spacing: 0) {
                TrafficLightButtons()
                    .padding(.leading, 12)
                Spacer()
            }
            .frame(height: 50)

            Rectangle().fill(themeColors.border).frame(height: 1)

            // 返回按钮
            Button {
                appViewModel.hideSettings()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(L10n.tr(.settingsBackToApp, language: language))
                        .font(.system(size: 12))
                }
                .foregroundStyle(themeColors.fgSecondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 16)

            // 菜单项
            SettingsMenuItemView(
                title: L10n.tr(.settingsTabGeneral, language: language),
                icon: "gearshape",
                isSelected: appViewModel.settingsTab == .general
            ) {
                appViewModel.settingsTab = .general
            }

            SettingsMenuItemView(
                title: L10n.tr(.settingsTabAppearance, language: language),
                icon: "paintbrush",
                isSelected: appViewModel.settingsTab == .appearance
            ) {
                appViewModel.settingsTab = .appearance
            }

            Spacer()
        }
        .background(themeColors.bgSubtle)
    }
}

private struct SettingsMenuItemView: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .foregroundStyle(isSelected ? themeColors.ink : themeColors.fgSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(isSelected ? themeColors.accentSoft : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }
}

// MARK: - 设置内容视图

/// 设置模式下的右侧内容区域
struct SettingsContentView: View {
    let appViewModel: AppViewModel
    @Bindable var settings: SettingsModel
    @Environment(\.themeColors) private var themeColors

    private var currentLanguage: Language {
        settings.languagePref.resolvedLanguage
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch appViewModel.settingsTab {
                case .general:
                    GeneralSettingsView(settings: settings, language: currentLanguage)
                case .appearance:
                    AppearanceSettingsView(settings: settings, language: currentLanguage)
                }
            }
            .frame(minWidth: 480, maxWidth: 896)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 40)
            .padding(.vertical, 40)
        }
        .scrollIndicators(.automatic)
        .scrollContentBackground(.hidden)
        .background(themeColors.surface, in: .rect(
            topLeadingRadius: 10,
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        ))
        .background(themeColors.bgElevated)
        .overlay(
            LeftEdgeShape(radius: 10)
                .stroke(themeColors.border, lineWidth: 1)
        )
    }
}

// MARK: - 全屏状态监听

private struct FullScreenStateModifier: ViewModifier {
    let appViewModel: AppViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
                appViewModel.isFullScreen = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
                appViewModel.isFullScreen = false
            }
    }
}

// MARK: - 快捷键监听

private struct KeyboardShortcutModifier: ViewModifier {
    let appViewModel: AppViewModel
    let documentViewModel: DocumentViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                appViewModel.toggleSidebar()
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToRendered)) { _ in
                documentViewModel.switchDisplayMode(.rendered)
            }
            .onReceive(NotificationCenter.default.publisher(for: .switchToRaw)) { _ in
                documentViewModel.switchDisplayMode(.raw)
            }
    }
}

// MARK: - 文件打开通知

private struct FileOpenModifier: ViewModifier {
    let appViewModel: AppViewModel
    let documentViewModel: DocumentViewModel
    let fileTreeViewModel: FileTreeViewModel
    let settings: SettingsModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .openDirectory)) { notification in
                if let url = notification.object as? URL {
                    appViewModel.openDirectory(url)
                    settings.lastOpenedDirectory = url
                    settings.lastOpenedFile = nil
                    settings.addRecentItem(url: url, isDirectory: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openFile)) { notification in
                if let url = notification.object as? URL {
                    appViewModel.openSingleFile(url)
                    fileTreeViewModel.selectedFileURL = url
                    settings.lastOpenedDirectory = nil
                    settings.lastOpenedFile = url
                    settings.addRecentItem(url: url, isDirectory: false)
                    Task {
                        await documentViewModel.loadFile(at: url)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openPanel)) { _ in
                OpenPanelHelper.show(language: settings.languagePref.resolvedLanguage)
            }
    }
}

// MARK: - 目录变化

private struct DirectoryChangeModifier: ViewModifier {
    let appViewModel: AppViewModel
    let documentViewModel: DocumentViewModel
    let fileTreeViewModel: FileTreeViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: appViewModel.rootDirectory) { _, newDirectory in
                if let dir = newDirectory {
                    documentViewModel.clearDocument()
                    Task {
                        await fileTreeViewModel.loadDirectory(dir)
                    }
                }
            }
    }
}

// MARK: - 文件选中变化

private struct SelectionChangeModifier: ViewModifier {
    let appViewModel: AppViewModel
    let documentViewModel: DocumentViewModel
    let fileTreeViewModel: FileTreeViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: fileTreeViewModel.selectedFileURL) { _, newURL in
                if let url = newURL {
                    Task {
                        await documentViewModel.loadFile(at: url)
                    }
                    let node = findFileNode(in: fileTreeViewModel.nodes, url: url)
                    appViewModel.selectedFile = node
                }
            }
    }

    private func findFileNode(in nodes: [FileNode], url: URL) -> FileNode? {
        for node in nodes {
            if node.path == url { return node }
            if node.isDirectory, let children = node.children {
                if let found = findFileNode(in: children, url: url) { return found }
            }
        }
        return nil
    }
}

// MARK: - 设置变化

private struct SettingsChangeModifier: ViewModifier {
    let appViewModel: AppViewModel
    let fileTreeViewModel: FileTreeViewModel
    let settings: SettingsModel

    func body(content: Content) -> some View {
        content
            .onChange(of: settings.showHiddenFiles) { _, _ in reloadFileTree() }
            .onChange(of: settings.showNonMarkdownFiles) { _, _ in reloadFileTree() }
    }

    private func reloadFileTree() {
        guard let dir = appViewModel.rootDirectory else { return }
        fileTreeViewModel.selectedFileURL = nil
        Task {
            await fileTreeViewModel.loadDirectory(dir)
        }
    }
}

// MARK: - 切换设置（Cmd+,）

private struct ToggleSettingsModifier: ViewModifier {
    let appViewModel: AppViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .toggleSettings)) { _ in
                appViewModel.toggleSettings()
            }
    }
}

// MARK: - 隐藏红绿灯

/// 通过 NSViewRepresentable 隐藏窗口红绿灯按钮
/// viewDidMoveToWindow 在视图挂载到窗口时调用，确保能获取到 window 实例
private struct TrafficLightHider: NSViewRepresentable {
    let bgColor: Color

    func makeNSView(context: Context) -> NSView {
        let view = TrafficLightObserverView()
        view.bgColor = NSColor(bgColor)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let observer = nsView as? TrafficLightObserverView {
            observer.bgColor = NSColor(bgColor)
            observer.updateWindowBackground()
        }
    }

    private final class TrafficLightObserverView: NSView {
        var bgColor: NSColor = .windowBackgroundColor

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            // 隐藏红绿灯按钮
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
            // 确保内容延伸到标题栏区域
            window.styleMask.insert(.fullSizeContentView)
            window.titlebarAppearsTransparent = true
            // 移除标题栏底部分隔线
            window.titlebarSeparatorStyle = .none
            // 设置窗口背景色匹配 bgSubtle
            updateWindowBackground()
            // 初始化 NSWindow.undoManager swizzling
            // 替换窗口的 undoManager getter 返回 per-file UndoManager
            NSWindow.swizzleUndoManager()
        }

        func updateWindowBackground() {
            guard let window else { return }
            window.backgroundColor = bgColor
        }
    }
}
