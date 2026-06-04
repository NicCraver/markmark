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
                fileTreeViewModel: fileTreeViewModel,
                settings: settings
            ))
            .modifier(SettingsChangeModifier(
                appViewModel: appViewModel,
                fileTreeViewModel: fileTreeViewModel,
                settings: settings
            ))
            .modifier(ToggleSettingsModifier(appViewModel: appViewModel))
            .background(TrafficLightHider(bgColor: themeColors.bgSubtle))
            .background(WindowCloseGuard(documentViewModel: documentViewModel, settings: settings))
            .task {
                // 连接 FileTreeViewModel 与 DocumentViewModel
                fileTreeViewModel.documentViewModel = documentViewModel
                applyAppearance(settings.appearanceMode)

                // 检查 UserDefaults 中是否有待打开的文件（从 AppDelegate 写入）
                // 这是最可靠的后备机制：即使通知丢失（无窗口时），视图挂载后也能读取
                if let filePath = UserDefaults.standard.string(forKey: "pendingOpenFilePath") {
                    UserDefaults.standard.removeObject(forKey: "pendingOpenFilePath")
                    let url = URL(fileURLWithPath: filePath)
                    appViewModel.openSingleFile(url)
                    fileTreeViewModel.selectedFileURL = url
                    settings.lastOpenedDirectory = nil
                    settings.lastOpenedFile = url
                    settings.addRecentItem(url: url, isDirectory: false)
                    // 不需要显式调用 loadFile — selectedFileURL 变化会触发 SelectionChangeModifier 统一加载
                } else if let dirPath = UserDefaults.standard.string(forKey: "pendingOpenDirectoryPath") {
                    UserDefaults.standard.removeObject(forKey: "pendingOpenDirectoryPath")
                    let url = URL(fileURLWithPath: dirPath)
                    appViewModel.openDirectory(url)
                    settings.lastOpenedDirectory = url
                    settings.lastOpenedFile = nil
                    settings.addRecentItem(url: url, isDirectory: true)
                }
                // 不在此处调用 restoreLastLocation()
                // 冷启动时，applicationDidFinishLaunching 通过 .restoreLastLocation 通知处理
                // 这样可以确保通知在视图完全挂载后才发送，避免时序问题
            }
            .onReceive(NotificationCenter.default.publisher(for: .restoreLastLocation)) { _ in
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
            .onChange(of: documentViewModel.isUntitled) { _, isUntitled in
                if !isUntitled {
                    appViewModel.hasUnsavedUntitled = false
                    appViewModel.untitledFileName = ""
                }
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
                        appViewModel: appViewModel,
                        documentViewModel: documentViewModel
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
            // 不需要显式调用 loadFile — selectedFileURL 变化会触发 SelectionChangeModifier 统一加载
        } else {
            // 默认打开 ~/Documents，避免访问 Music 等受限目录触发权限弹窗
            let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
            appViewModel.openDirectory(documentsDir)
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
                guard let url = notification.object as? URL else { return }
                // 幂等保护：如果已经在显示此目录，跳过
                if appViewModel.rootDirectory == url { return }
                if documentViewModel.isUntitled && documentViewModel.isDirty {
                    handleUnsavedChangesBeforeAction { proceed in
                        guard proceed else { return }
                        appViewModel.openDirectory(url)
                        settings.lastOpenedDirectory = url
                        settings.lastOpenedFile = nil
                        settings.addRecentItem(url: url, isDirectory: true)
                    }
                } else {
                    appViewModel.openDirectory(url)
                    settings.lastOpenedDirectory = url
                    settings.lastOpenedFile = nil
                    settings.addRecentItem(url: url, isDirectory: true)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .openFile)) { notification in
                guard let url = notification.object as? URL else { return }
                // 幂等保护：如果已经在显示此文件，跳过（防止 application(_:open:) 和 .onOpenURL 同时触发导致重复打开）
                if documentViewModel.currentFileURL == url { return }
                if documentViewModel.isUntitled && documentViewModel.isDirty {
                    handleUnsavedChangesBeforeAction { proceed in
                        guard proceed else { return }
                        appViewModel.openSingleFile(url)
                        fileTreeViewModel.selectedFileURL = url
                        settings.lastOpenedDirectory = nil
                        settings.lastOpenedFile = url
                        settings.addRecentItem(url: url, isDirectory: false)
                        // 不需要显式调用 loadFile — selectedFileURL 变化会触发 SelectionChangeModifier 统一加载
                    }
                } else {
                    appViewModel.openSingleFile(url)
                    fileTreeViewModel.selectedFileURL = url
                    settings.lastOpenedDirectory = nil
                    settings.lastOpenedFile = url
                    settings.addRecentItem(url: url, isDirectory: false)
                    // 不需要显式调用 loadFile — selectedFileURL 变化会触发 SelectionChangeModifier 统一加载
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .newFile)) { _ in
                if documentViewModel.isUntitled && documentViewModel.isDirty {
                    handleUnsavedChangesBeforeAction { proceed in
                        guard proceed else { return }
                        let result = documentViewModel.createUntitledFile()
                        guard result != nil else { return }
                        fileTreeViewModel.selectedFileURL = nil
                        appViewModel.selectedFile = nil
                        appViewModel.hasUnsavedUntitled = true
                        appViewModel.untitledFileName = documentViewModel.fileName
                    }
                } else {
                    let result = documentViewModel.createUntitledFile()
                    guard result != nil else { return }
                    fileTreeViewModel.selectedFileURL = nil
                    appViewModel.selectedFile = nil
                    appViewModel.hasUnsavedUntitled = true
                    appViewModel.untitledFileName = documentViewModel.fileName
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveFile)) { _ in
                Task {
                    await documentViewModel.save()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .saveAsFile)) { _ in
                let language = settings.languagePref.resolvedLanguage
                let defaultDir = settings.lastOpenedDirectory ?? settings.lastOpenedFile?.deletingLastPathComponent()
                let suggestedName = documentViewModel.fileName.isEmpty ? "Untitled.md" : documentViewModel.fileName

                if let saveURL = OpenPanelHelper.showSavePanel(
                    language: language,
                    defaultDirectory: defaultDir,
                    suggestedName: suggestedName
                ) {
                    Task {
                        await documentViewModel.saveAs(to: saveURL)
                        appViewModel.hasUnsavedUntitled = false

                        if let rootDir = appViewModel.rootDirectory,
                           saveURL.path.hasPrefix(rootDir.path + "/") {
                            await fileTreeViewModel.loadDirectory(rootDir)
                            fileTreeViewModel.selectedFileURL = saveURL
                        }

                        // 更新最近打开记录
                        settings.lastOpenedFile = saveURL
                        settings.addRecentItem(url: saveURL, isDirectory: false)
                    }
                }
            }
    }

    /// 通用未保存修改弹窗处理
    /// 仅在临时新建文件（isUntitled && isDirty）有未保存更改时调用
    /// 弹窗确认后执行操作，保护临时文件内容不丢失
    /// - Parameter completion: 回调，`proceed` 为 true 表示用户选择保存或放弃，可继续操作；false 表示取消
    private func handleUnsavedChangesBeforeAction(completion: @escaping (_ proceed: Bool) -> Void) {
        let language = settings.languagePref.resolvedLanguage

        let alert = NSAlert()
        alert.messageText = L10n.tr(.unsavedChangesTitle, language: language)
        alert.informativeText = L10n.tr(.unsavedChangesMessage, language: language)
        alert.alertStyle = .warning

        alert.addButton(withTitle: L10n.tr(.unsavedSave, language: language))
        alert.addButton(withTitle: L10n.tr(.unsavedDontSave, language: language))
        alert.addButton(withTitle: L10n.tr(.unsavedCancel, language: language))

        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = "d"
        alert.buttons[1].keyEquivalentModifierMask = .command
        alert.buttons[2].keyEquivalent = "\u{1b}"

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // 保存：临时新建文件走另存为流程
            let defaultDir = settings.lastOpenedDirectory ?? settings.lastOpenedFile?.deletingLastPathComponent()
            let suggestedName = documentViewModel.fileName.isEmpty ? "Untitled.md" : documentViewModel.fileName

            if let saveURL = OpenPanelHelper.showSavePanel(
                language: language,
                defaultDirectory: defaultDir,
                suggestedName: suggestedName
            ) {
                Task {
                    await documentViewModel.saveAs(to: saveURL)
                    appViewModel.hasUnsavedUntitled = false

                    // 如果保存在当前目录下，刷新文件树
                    if let rootDir = appViewModel.rootDirectory,
                       saveURL.path.hasPrefix(rootDir.path + "/") {
                        await fileTreeViewModel.loadDirectory(rootDir)
                        fileTreeViewModel.selectedFileURL = saveURL
                    }

                    settings.lastOpenedFile = saveURL
                    settings.addRecentItem(url: saveURL, isDirectory: false)
                    completion(true)
                }
            } else {
                // 用户取消了另存为，不继续操作
                completion(false)
            }

        case .alertSecondButtonReturn:
            // 不保存
            documentViewModel.discardUntitledFile()
            appViewModel.hasUnsavedUntitled = false
            completion(true)

        default:
            // 取消
            completion(false)
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
                } else {
                    // 目录关闭（如切换到单文件模式）
                    // 跳过 clearDirectory()：文件树即将被隐藏，无需清空
                    // 如果用户重新打开目录，loadDirectory 会覆盖旧数据
                }
            }
    }
}

// MARK: - 文件选中变化

private struct SelectionChangeModifier: ViewModifier {
    let appViewModel: AppViewModel
    let documentViewModel: DocumentViewModel
    let fileTreeViewModel: FileTreeViewModel
    let settings: SettingsModel

    func body(content: Content) -> some View {
        content
            .onChange(of: fileTreeViewModel.selectedFileURL) { oldURL, newURL in
                if let url = newURL {
                    if documentViewModel.isUntitled && documentViewModel.isDirty {
                        handleFileSwitchWithUnsavedChanges(from: oldURL, to: url)
                    } else {
                        Task {
                            await documentViewModel.loadFile(at: url)
                        }
                        let node = findFileNode(in: fileTreeViewModel.nodes, url: url)
                        appViewModel.selectedFile = node
                    }
                } else {
                    if let deletedURL = oldURL,
                       !FileManager.default.fileExists(atPath: deletedURL.path),
                       documentViewModel.isDirty {
                        handleDeletedFileWithUnsavedChanges(deletedURL)
                    } else if !documentViewModel.isUntitled {
                        // 仅在非 untitled 文件时取消选中
                        // untitled 文件不在文件树中，selectedFileURL 变为 nil 是正常的，
                        // 不应重置文档状态
                        documentViewModel.deselectCurrentFile()
                    }
                    appViewModel.selectedFile = nil
                }
            }
    }

    /// 文件切换时的未保存修改弹窗（仅临时新建文件触发）
    private func handleFileSwitchWithUnsavedChanges(from oldURL: URL?, to newURL: URL) {
        guard documentViewModel.currentFileURL != newURL else { return }

        let language = settings.languagePref.resolvedLanguage

        let alert = NSAlert()
        alert.messageText = L10n.tr(.unsavedChangesTitle, language: language)
        alert.informativeText = L10n.tr(.unsavedChangesMessage, language: language)
        alert.alertStyle = .warning

        alert.addButton(withTitle: L10n.tr(.unsavedSave, language: language))
        alert.addButton(withTitle: L10n.tr(.unsavedDontSave, language: language))
        alert.addButton(withTitle: L10n.tr(.unsavedCancel, language: language))

        alert.buttons[0].keyEquivalent = "\r"
        alert.buttons[1].keyEquivalent = "d"
        alert.buttons[1].keyEquivalentModifierMask = .command
        alert.buttons[2].keyEquivalent = "\u{1b}"

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // 保存：临时新建文件走另存为流程
            let defaultDir = settings.lastOpenedDirectory ?? settings.lastOpenedFile?.deletingLastPathComponent()
            let suggestedName = documentViewModel.fileName.isEmpty ? "Untitled.md" : documentViewModel.fileName

            if let saveURL = OpenPanelHelper.showSavePanel(
                language: language,
                defaultDirectory: defaultDir,
                suggestedName: suggestedName
            ) {
                Task {
                    await documentViewModel.saveAs(to: saveURL)
                    appViewModel.hasUnsavedUntitled = false
                    await documentViewModel.loadFile(at: newURL)
                    let node = findFileNode(in: fileTreeViewModel.nodes, url: newURL)
                    appViewModel.selectedFile = node

                    if let rootDir = appViewModel.rootDirectory,
                       saveURL.path.hasPrefix(rootDir.path + "/") {
                        await fileTreeViewModel.loadDirectory(rootDir)
                        fileTreeViewModel.selectedFileURL = saveURL
                    }
                }
            } else {
                fileTreeViewModel.selectedFileURL = oldURL
            }

        case .alertSecondButtonReturn:
            documentViewModel.discardUntitledFile()
            appViewModel.hasUnsavedUntitled = false
            Task {
                await documentViewModel.loadFile(at: newURL)
            }
            let node = findFileNode(in: fileTreeViewModel.nodes, url: newURL)
            appViewModel.selectedFile = node

        default:
            fileTreeViewModel.selectedFileURL = oldURL
        }
    }

    /// 处理文件被外部删除且有未保存修改的情况
    private func handleDeletedFileWithUnsavedChanges(_ deletedURL: URL) {
        let language = settings.languagePref.resolvedLanguage
        let fileName = deletedURL.lastPathComponent

        let alert = NSAlert()
        alert.messageText = L10n.tr(.fileDeletedTitle, language: language)
        alert.informativeText = L10n.tr(.fileDeletedMessage, language: language, args: ["name": fileName])
        alert.alertStyle = .warning

        alert.addButton(withTitle: L10n.tr(.fileDeletedSaveAs, language: language))
        alert.addButton(withTitle: L10n.tr(.fileDeletedDiscard, language: language))

        // 「另存为」为默认按钮（回车键）
        alert.buttons[0].keyEquivalent = "\r"
        // 「放弃更改」为 Esc 或 Cmd+D
        alert.buttons[1].keyEquivalent = "d"
        alert.buttons[1].keyEquivalentModifierMask = .command

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            // 另存为
            let defaultDir = settings.lastOpenedDirectory ?? deletedURL.deletingLastPathComponent()
            let suggestedName = documentViewModel.fileName.isEmpty ? "Untitled.md" : documentViewModel.fileName

            if let saveURL = OpenPanelHelper.showSavePanel(
                language: language,
                defaultDirectory: defaultDir,
                suggestedName: suggestedName
            ) {
                Task {
                    await documentViewModel.saveAs(to: saveURL)
                    documentViewModel.deselectCurrentFile()
                    appViewModel.selectedFile = nil

                    // 如果保存在当前目录下，刷新文件树并选中
                    if let rootDir = appViewModel.rootDirectory,
                       saveURL.path.hasPrefix(rootDir.path) {
                        await fileTreeViewModel.refreshDirectory()
                        fileTreeViewModel.selectedFileURL = saveURL
                    }
                }
            } else {
                // 用户取消了另存为，保留当前文档内容让用户继续操作
                // 但文件树中已无此文件，需要重新选中以避免状态不一致
                appViewModel.selectedFile = nil
            }

        default:
            // 放弃更改
            documentViewModel.deselectCurrentFile()
            appViewModel.selectedFile = nil
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
            .onChange(of: settings.languagePref.resolvedLanguage) { _, newLanguage in
                fileTreeViewModel.language = newLanguage
            }
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

// MARK: - 窗口关闭保护（未保存更改提醒）

/// 通过 NSViewRepresentable 设置窗口代理，在关闭前检查未保存更改
/// 使用 performClose 触发 windowShouldClose，展示保存/不保存/取消对话框
private struct WindowCloseGuard: NSViewRepresentable {
    let documentViewModel: DocumentViewModel
    let settings: SettingsModel

    func makeNSView(context: Context) -> NSView {
        let view = WindowCloseGuardView()
        view.documentViewModel = documentViewModel
        view.settings = settings
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? WindowCloseGuardView)?.documentViewModel = documentViewModel
        (nsView as? WindowCloseGuardView)?.settings = settings
    }

    /// 持有窗口代理的 NSView，在 viewDidMoveToWindow 中设置代理
    private final class WindowCloseGuardView: NSView, NSWindowDelegate {
        weak var documentViewModel: DocumentViewModel?
        weak var settings: SettingsModel?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.delegate = self
        }

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            guard let doc = documentViewModel else { return true }

            // 仅对临时新建文件且有未保存更改时弹窗提醒
            // 普通脏文件（已保存在磁盘）允许自由关闭，不弹窗
            if !(doc.isUntitled && doc.isDirty) { return true }

            let language = settings?.languagePref.resolvedLanguage ?? .en

            // 显示未保存更改提醒
            let alert = NSAlert()
            alert.messageText = L10n.tr(.unsavedChangesTitle, language: language)
            alert.informativeText = L10n.tr(.unsavedChangesMessage, language: language)
            alert.alertStyle = .warning

            alert.addButton(withTitle: L10n.tr(.unsavedSave, language: language))
            alert.addButton(withTitle: L10n.tr(.unsavedDontSave, language: language))
            alert.addButton(withTitle: L10n.tr(.unsavedCancel, language: language))

            // 设置「保存」为默认按钮（回车键）
            alert.buttons[0].keyEquivalent = "\r"
            // 设置「不保存」为 Cmd+D 快捷键
            alert.buttons[1].keyEquivalent = "d"
            alert.buttons[1].keyEquivalentModifierMask = .command
            // 设置「取消」为 Esc 键
            alert.buttons[2].keyEquivalent = "\u{1b}"

            let response = alert.runModal()

            switch response {
            case .alertFirstButtonReturn:
                // 保存：临时新建文件走另存为流程
                let defaultDir = settings?.lastOpenedDirectory ?? settings?.lastOpenedFile?.deletingLastPathComponent()
                let suggestedName = doc.fileName.isEmpty ? "Untitled.md" : doc.fileName

                if let saveURL = OpenPanelHelper.showSavePanel(
                    language: language,
                    defaultDirectory: defaultDir,
                    suggestedName: suggestedName
                ) {
                    Task {
                        await doc.saveAs(to: saveURL)
                        // 保存成功后关闭窗口
                        sender.close()
                    }
                }
                // 用户取消了另存为，不关闭窗口
                return false

            case .alertSecondButtonReturn:
                // 不保存，清理临时文件后关闭
                if let url = doc.currentFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                return true

            default:
                // 取消，不关闭窗口
                return false
            }
        }
    }
}
