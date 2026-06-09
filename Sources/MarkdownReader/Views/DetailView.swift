import SwiftUI
import MarkdownReaderKit
import WebKit

/// 仅绘制左侧边缘（含圆角）的 Shape，用于左边框描边
struct LeftEdgeShape: Shape {
    var radius: CGFloat = 10

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // 从顶部开始，绘制左上圆角
        path.move(to: CGPoint(x: radius, y: 0))
        path.addArc(
            tangent1End: CGPoint(x: 0, y: 0),
            tangent2End: CGPoint(x: 0, y: radius),
            radius: radius
        )
        // 左侧直线
        path.addLine(to: CGPoint(x: 0, y: rect.height - radius))
        // 左下圆角
        path.addArc(
            tangent1End: CGPoint(x: 0, y: rect.height),
            tangent2End: CGPoint(x: radius, y: rect.height),
            radius: radius
        )
        return path
    }
}

/// 右侧主体区容器（圆角），包含内容区和底部项目状态栏
struct DetailView: View {
    let appViewModel: AppViewModel
    let documentViewModel: DocumentViewModel
    let fileTreeViewModel: FileTreeViewModel
    let settings: SettingsModel
    @Environment(\.language) private var language
    @Environment(\.themeColors) private var themeColors

    /// 查找替换 ViewModel
    @State private var findReplaceViewModel = FindReplaceViewModel()

    /// NSTextView 搜索引用，用于 Raw 模式搜索/高亮/替换
    @State private var textViewSearchRef = TextViewSearchRef()

    /// 刷新确认弹窗状态
    @State private var showReloadAlert = false
    @State private var dontRemindAgain = false

    @State private var isDropTargeted = false

    @State private var showUnsupportedFileAlert = false
    @State private var unsupportedFileExt = ""

    /// 渲染模式下当前可见标题的行号（用于大纲高亮同步）
    @State private var activeOutlineLineNumber: Int?

    /// PDF 导出失败提示
    @State private var showExportPDFError = false

    /// 导出 / CriticMarkup 复用的 WKWebView 句柄
    @State private var webViewHandle = WebViewHandle()

    /// 复制后的短暂反馈（图标切换为对勾）
    @State private var didCopy = false

    /// 清除标注确认弹窗
    @State private var showClearAnnotationsAlert = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            Rectangle().fill(themeColors.border).frame(height: 1)

            // 内容区域
            contentArea
                .overlay {
                    if isDropTargeted {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeColors.accent, lineWidth: 2)
                            .padding(4)
                    }
                }
        }
        .background(themeColors.surface, in: .rect(
            topLeadingRadius: 10,
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        ))
        .clipShape(.rect(
            topLeadingRadius: 10,
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 0,
            topTrailingRadius: 0
        ))
        .background(themeColors.bgSubtle)
        .overlay(
            LeftEdgeShape(radius: 10)
                .stroke(themeColors.border, lineWidth: 1)
        )
        .onReceive(NotificationCenter.default.publisher(for: .reloadFile)) { _ in
            handleReloadButtonTapped()
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportPDF)) { _ in
            exportPDF()
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyForAI)) { _ in
            copyForAI()
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearAnnotations)) { _ in
            if documentHasAnnotations { showClearAnnotationsAlert = true }
        }
        .alert(L10n.tr(.clearAnnotationsConfirmTitle, language: language), isPresented: $showClearAnnotationsAlert) {
            Button(L10n.tr(.clearAnnotationsMenu, language: language), role: .destructive) {
                clearAnnotations()
            }
            Button(L10n.tr(.unsavedCancel, language: language), role: .cancel) {}
        } message: {
            Text(L10n.tr(.clearAnnotationsConfirmMessage, language: language))
        }
        // 拖拽视觉反馈：由 AppKit FileDropOverlayView 发送
        .onReceive(NotificationCenter.default.publisher(for: .dragHoverChanged)) { notification in
            if let isTargeted = notification.object as? Bool {
                isDropTargeted = isTargeted
            }
        }
        // 不支持文件类型提示：由 AppKit FileDropOverlayView 发送
        .onReceive(NotificationCenter.default.publisher(for: .unsupportedFileTypeDropped)) { notification in
            if let ext = notification.object as? String {
                unsupportedFileExt = ext
                showUnsupportedFileAlert = true
            }
        }
        .alert(L10n.tr(.exportPDFFailed, language: language), isPresented: $showExportPDFError) {
            Button(L10n.tr(.confirm, language: language), role: .cancel) {}
        }
        .alert(
            L10n.tr(.unsupportedFileTypeAlert, language: language, args: ["ext": unsupportedFileExt]),
            isPresented: $showUnsupportedFileAlert
        ) {
            Button(L10n.tr(.confirm, language: language), role: .cancel) {}
        }
    }

    // MARK: - TitleBar

    @ViewBuilder
    private var titleBar: some View {
        HStack(spacing: 0) {
            if !appViewModel.isSidebarVisible {
                TrafficLightButtons()
                    .padding(.leading, 12)

                Button {
                    appViewModel.toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 14))
                        .foregroundStyle(themeColors.fgSecondary)
                }
                .buttonStyle(.plain)
                .help(L10n.tr(.titleBarToggleSidebar, language: language))
                .padding(.leading, 8)

                Button {
                    OpenPanelHelper.show(language: language)
                } label: {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(themeColors.fgSecondary)
                }
                .buttonStyle(.plain)
                .help(L10n.tr(.titleBarOpen, language: language))
                .padding(.leading, 4)

                // 新建文件按钮（始终可用，无需打开目录）
                Button {
                    NotificationCenter.default.post(name: .newFile, object: nil)
                } label: {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 14))
                        .foregroundStyle(themeColors.fgSecondary)
                }
                .buttonStyle(.plain)
                .help(L10n.tr(.titleBarNewFile, language: language))
                .padding(.leading, 4)
            }

            // 文件路径或 Untitled 标识（左对齐，仅在有文档时显示）
            if documentViewModel.hasDocument {
                if documentViewModel.isUntitled {
                    Text(documentViewModel.fileName)
                        .font(.system(size: 12))
                        .foregroundStyle(themeColors.fgMuted)
                        .padding(.leading, 12)
                } else if let path = documentViewModel.currentFileURL?.path {
                    Text(path)
                        .font(.system(size: 12))
                        .foregroundStyle(themeColors.fgMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.leading, 12)

                    Button {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString(path, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundStyle(themeColors.fgMuted)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr(.titleBarCopyPath, language: language))
                    .padding(.leading, 2)
                }
            }

            Spacer()

            // 渲染 / 编辑模式切换已移除：MarkMark 是纯阅读 + 标注，无编辑需求。
            // 纯文本（.txt）文件无法渲染，仍以原文视图展示（见 documentContentView）。

            // 操作按钮组与大纲图标下对齐，横向间隔一致
            HStack(alignment: .bottom, spacing: 8) {
                // 刷新按钮（文件被外部修改时显示，在保存按钮左侧）
                if documentViewModel.hasDocument && documentViewModel.isFileModifiedExternally {
                    Button {
                        handleReloadButtonTapped()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                            .foregroundStyle(themeColors.accent)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr(.titleBarReload, language: language))
                }

                // 保存按钮（在渲染模式切换右侧）
                if documentViewModel.hasDocument {
                    Button {
                        NotificationCenter.default.post(name: .saveFile, object: nil)
                    } label: {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(documentViewModel.isDirty ? themeColors.accent : themeColors.fgMuted)
                    }
                    .buttonStyle(.plain)
                    .disabled(!documentViewModel.isDirty)
                    .help(L10n.tr(.titleBarSave, language: language))

                    Button {
                        exportPDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14))
                            .foregroundStyle(themeColors.fgMuted)
                    }
                    .buttonStyle(.plain)
                    .help(L10n.tr(.titleBarExportPDF, language: language))

                    // 清除全部 CriticMarkup 标注（仅当存在标注时显示）
                    if documentHasAnnotations {
                        Button {
                            showClearAnnotationsAlert = true
                        } label: {
                            Image(systemName: "eraser")
                                .font(.system(size: 14))
                                .foregroundStyle(themeColors.fgMuted)
                        }
                        .buttonStyle(.plain)
                        .help(L10n.tr(.titleBarClearAnnotations, language: language))
                    }

                    // 复制：默认复制 CriticMarkup 原文；下拉可「复制给 AI（含说明）」
                    Menu {
                        Button {
                            copyCritic()
                        } label: {
                            Label(L10n.tr(.copyCriticMenu, language: language), systemImage: "doc.on.doc")
                        }
                        Button {
                            copyForAI()
                        } label: {
                            Label(L10n.tr(.copyForAIMenu, language: language), systemImage: "sparkles")
                        }
                    } label: {
                        Image(systemName: didCopy ? "checkmark.circle.fill" : "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundStyle(didCopy ? themeColors.accent : themeColors.fgMuted)
                    } primaryAction: {
                        copyCritic()
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(L10n.tr(.titleBarCopyMenu, language: language))
                }

                // 大纲切换按钮（始终显示在 titlebar 最右侧）
                Button {
                    appViewModel.toggleOutline()
                } label: {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 14))
                        .foregroundStyle(outlineButtonColor)
                }
                .buttonStyle(.plain)
                .disabled(!documentViewModel.hasDocument)
                .help(L10n.tr(.titleBarToggleOutline, language: language))
            }
            .padding(.trailing, 12)
        }
        .frame(height: 50)
        .background(WindowDragArea())
        .alert(L10n.tr(.fileModifiedExternallyTitle, language: language), isPresented: $showReloadAlert) {
            Button(L10n.tr(.fileModifiedExternallyReload, language: language), role: .destructive) {
                Task {
                    await documentViewModel.reloadFromDisk()
                }
                if dontRemindAgain {
                    settings.skipFileModifiedAlert = true
                }
            }
            Button(L10n.tr(.unsavedCancel, language: language), role: .cancel) {
                dontRemindAgain = false
            }
        } message: {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.tr(.fileModifiedExternallyMessage, language: language))
                Toggle(L10n.tr(.fileModifiedExternallyDontRemind, language: language), isOn: $dontRemindAgain)
            }
        }
    }

    // MARK: - 内容区

    @ViewBuilder
    private var contentArea: some View {
        if documentViewModel.hasDocument {
            documentContentWithOutline
        } else if appViewModel.rootDirectory == nil && !appViewModel.isSingleFileMode {
            WelcomeView(appViewModel: appViewModel)
        } else if let error = documentViewModel.fileError {
            ErrorView(
                icon: "exclamationmark.triangle",
                message: error.localizedDescription
            )
        } else if documentViewModel.isLoading {
            // 仅在首次加载（无已有文档）时显示进度指示器
            ProgressView()
                .tint(themeColors.fgSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if !appViewModel.isSingleFileMode && fileTreeViewModel.isEmptyDirectory {
            ErrorView(
                icon: "folder",
                message: L10n.tr(.emptyDirectoryMessage, language: language)
            )
        } else {
            selectFilePlaceholder
        }
    }

    // MARK: - 文档内容（带大纲分栏）

    @ViewBuilder
    private var documentContentWithOutline: some View {
        HStack(spacing: 0) {
            // 左侧：Markdown 主内容区
            documentContentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // 右侧：大纲侧边栏
            if appViewModel.isOutlineVisible {
                OutlineResizeHandle(appViewModel: appViewModel)

                outlineSidebar
                    .frame(width: appViewModel.outlineWidth)
            }
        }
    }

    // MARK: - 大纲侧边栏

    /// 大纲按钮颜色：激活时强调色，有文档时次要色，无文档时弱化色
    /// 处理刷新按钮点击
    private func handleReloadButtonTapped() {
        if documentViewModel.isDirty && !settings.skipFileModifiedAlert {
            showReloadAlert = true
        } else {
            Task {
                await documentViewModel.reloadFromDisk()
            }
        }
    }

    // MARK: - CriticMarkup

    /// 当前文档是否包含 CriticMarkup 标注
    private var documentHasAnnotations: Bool {
        CriticMarkup.hasMarkup(documentViewModel.content)
    }

    /// 传给渲染视图选词工具条的本地化文案
    private var criticLabels: [String: String] {
        [
            "delete": L10n.tr(.criticDelete, language: language),
            "highlight": L10n.tr(.criticHighlight, language: language),
            "comment": L10n.tr(.criticComment, language: language),
            "replace": L10n.tr(.criticReplace, language: language),
            "confirm": L10n.tr(.criticConfirm, language: language),
            "cancel": L10n.tr(.criticCancel, language: language),
            "edit": L10n.tr(.criticEdit, language: language),
            "commentHint": L10n.tr(.criticCommentHint, language: language),
            "replaceHint": L10n.tr(.criticReplaceHint, language: language),
        ]
    }

    /// 复制带标注的文档（含引导提示词）到剪贴板，供粘贴给 AI
    private func copyForAI() {
        guard documentViewModel.hasDocument else { return }
        writeToPasteboard(CriticMarkup.exportForAI(documentViewModel.content))
    }

    /// 复制带 CriticMarkup 标注的原文（不含 AI 引导说明）
    private func copyCritic() {
        guard documentViewModel.hasDocument else { return }
        writeToPasteboard(documentViewModel.content)
    }

    private func writeToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        didCopy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            didCopy = false
        }
    }

    /// 清除全部标注，恢复原文
    private func clearAnnotations() {
        guard documentViewModel.hasDocument else { return }
        documentViewModel.content = CriticMarkup.rejecting(documentViewModel.content)
    }

    private func exportPDF() {
        guard documentViewModel.hasDocument else { return }
        let language = settings.languagePref.resolvedLanguage
        let stem = URL(fileURLWithPath: documentViewModel.fileName).deletingPathExtension().lastPathComponent
        let suggestedName = stem.isEmpty ? "Untitled.pdf" : "\(stem).pdf"
        let defaultDir = settings.lastOpenedDirectory
            ?? documentViewModel.currentFileURL?.deletingLastPathComponent()

        guard let saveURL = OpenPanelHelper.showExportPDFPanel(
            language: language,
            defaultDirectory: defaultDir,
            suggestedName: suggestedName
        ) else { return }

        Task {
            await exportPDF(to: saveURL)
        }
    }

    private func exportPDF(to url: URL) async {
        do {
            let data: Data
            if let webView = webViewHandle.webView, documentViewModel.displayMode == .rendered {
                data = try await PDFExportService.exportFromWebView(webView)
            } else {
                let baseURL = documentViewModel.currentFileURL?.deletingLastPathComponent()
                let contentWidth: CGFloat
                if settings.maxContentWidthFollowsWindow {
                    contentWidth = max(980, NSApp.keyWindow?.contentRect(forFrameRect: NSApp.keyWindow?.frame ?? .zero).width ?? 980)
                } else {
                    contentWidth = 980
                }
                let html = MarkdownHTMLService.buildFullHTML(
                    content: documentViewModel.content,
                    themeCSS: themeColors.cssCustomProperties + themeColors.codeHighlightCSS,
                    contentPadding: settings.contentPaddingPoints,
                    maxContentWidthFollowsWindow: settings.maxContentWidthFollowsWindow,
                    baseURL: baseURL,
                    isDark: settings.resolvedThemeType == .dark
                )
                data = try await PDFExportService.export(
                    html: html,
                    baseURL: baseURL,
                    contentWidth: contentWidth,
                    contentPadding: settings.contentPaddingPoints
                )
            }
            try data.write(to: url)
        } catch {
            showExportPDFError = true
        }
    }

    private var outlineButtonColor: Color {
        if appViewModel.isOutlineVisible {
            return themeColors.accent
        } else if documentViewModel.hasDocument {
            return themeColors.fgSecondary
        } else {
            return themeColors.fgMuted
        }
    }

    private var outlineSidebar: some View {
        OutlineView(
            items: documentViewModel.outlineItems,
            onSelect: { item in
                documentViewModel.requestScrollToLine(item.lineNumber)
            },
            activeLineNumber: activeOutlineLineNumber
        )
    }

    // MARK: - 查找替换

    private func openFindBar() {
        if !appViewModel.isFindBarVisible {
            appViewModel.showFindBar()
        }
    }

    private func openFindAndReplace() {
        if !appViewModel.isFindBarVisible {
            appViewModel.showFindBar()
        }
        findReplaceViewModel.expandReplace()
    }

    private func closeFindBar() {
        textViewSearchRef.clearSearchHighlights()
        findReplaceViewModel.clearSearch()
        appViewModel.hideFindBar()
    }

    private func performSearch() {
        let text = documentViewModel.content
        findReplaceViewModel.performSearch(in: text)

        if documentViewModel.displayMode == .raw {
            if findReplaceViewModel.hasResults {
                textViewSearchRef.reapplySearchHighlights(
                    matchRanges: findReplaceViewModel.matchRanges,
                    currentIndex: findReplaceViewModel.currentMatchIndex
                )
                textViewSearchRef.selectMatch(
                    at: findReplaceViewModel.currentMatchIndex,
                    in: findReplaceViewModel.matchRanges
                )
            } else {
                textViewSearchRef.clearSearchHighlights()
            }
        } else if findReplaceViewModel.hasResults {
            if let line = findReplaceViewModel.currentMatchLine {
                documentViewModel.requestScrollToLine(line)
            }
        }
    }

    private func performFindNext() {
        guard findReplaceViewModel.hasResults else {
            if !appViewModel.isFindBarVisible { openFindBar() }
            performSearch()
            return
        }
        findReplaceViewModel.goToNextMatch()
        navigateToCurrentMatch()
    }

    private func performFindPrevious() {
        guard findReplaceViewModel.hasResults else {
            if !appViewModel.isFindBarVisible { openFindBar() }
            performSearch()
            return
        }
        findReplaceViewModel.goToPreviousMatch()
        navigateToCurrentMatch()
    }

    private func navigateToCurrentMatch() {
        if documentViewModel.displayMode == .raw {
            textViewSearchRef.reapplySearchHighlights(
                matchRanges: findReplaceViewModel.matchRanges,
                currentIndex: findReplaceViewModel.currentMatchIndex
            )
            textViewSearchRef.selectMatch(
                at: findReplaceViewModel.currentMatchIndex,
                in: findReplaceViewModel.matchRanges
            )
        } else if let line = findReplaceViewModel.currentMatchLine {
            documentViewModel.requestScrollToLine(line)
        }
    }

    private func performReplace() {
        guard documentViewModel.displayMode == .raw,
              let currentRange = findReplaceViewModel.currentMatchRange else { return }

        let _ = textViewSearchRef.replaceCurrentMatch(at: currentRange, with: findReplaceViewModel.replaceText)
        documentViewModel.content = textViewSearchRef.textView?.string ?? documentViewModel.content
        performSearch()
    }

    private func performReplaceAll() {
        guard documentViewModel.displayMode == .raw,
              !findReplaceViewModel.matchRanges.isEmpty else { return }

        let _ = textViewSearchRef.replaceAllMatches(ranges: findReplaceViewModel.matchRanges, with: findReplaceViewModel.replaceText)
        documentViewModel.content = textViewSearchRef.textView?.string ?? documentViewModel.content
        performSearch()
    }

    // MARK: - 文档内容视图

    @ViewBuilder
    private var selectFilePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 36))
                .foregroundStyle(themeColors.fgMuted)
            Text(L10n.tr(.selectFileHint, language: language))
                .font(.subheadline)
                .foregroundStyle(themeColors.fgSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 文档内容视图

    @ViewBuilder
    private var documentContentView: some View {
        ZStack {
            // 纯文本（.txt）文件无法渲染，用原文视图展示（只读阅读，无编辑切换）
            if documentViewModel.isPlainTextMode {
                RawMarkdownView(
                    content: Binding(
                        get: { documentViewModel.content },
                        set: { documentViewModel.content = $0 }
                    ),
                    fontSize: settings.sourceFontPointSize,
                    contentPadding: settings.contentPaddingPoints,
                    scrollToLine: documentViewModel.scrollToLineRequest,
                    fileURL: documentViewModel.currentFileURL,
                    isActive: true,
                    isFindBarVisible: appViewModel.isFindBarVisible,
                    searchRef: textViewSearchRef,
                    onCursorLineNumberChanged: { lineNumber in
                        documentViewModel.cursorLineNumber = lineNumber
                    }
                )
                .onChange(of: documentViewModel.scrollToLineRequest) { _, newValue in
                    if newValue != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            documentViewModel.clearScrollRequest()
                        }
                    }
                }
            } else {
                // Markdown：仅渲染视图（无编辑界面）
                WebViewMarkdownView(
                    content: documentViewModel.content,
                    fileURL: documentViewModel.currentFileURL,
                    contentPadding: settings.contentPaddingPoints,
                    maxContentWidthFollowsWindow: settings.maxContentWidthFollowsWindow,
                    scrollToLine: documentViewModel.scrollToLineRequest,
                    themeCSS: themeColors.cssCustomProperties + themeColors.codeHighlightCSS,
                    isDark: settings.resolvedThemeType == .dark,
                    searchQuery: findReplaceViewModel.searchText,
                    searchCaseSensitive: findReplaceViewModel.isCaseSensitive,
                    searchWholeWord: findReplaceViewModel.isWholeWord,
                    searchCurrentIndex: findReplaceViewModel.currentMatchIndex,
                    isFindBarVisible: appViewModel.isFindBarVisible,
                    onVisibleHeadingChanged: { heading in
                        activeOutlineLineNumber = heading?.lineNumber
                    },
                    onVisibleLineChanged: { lineNumber in
                        documentViewModel.renderedVisibleLineNumber = lineNumber
                    },
                    onCriticAction: { action in
                        documentViewModel.applyCriticAction(action)
                    },
                    criticLabels: criticLabels,
                    handle: webViewHandle
                )
                .onChange(of: documentViewModel.scrollToLineRequest) { _, newValue in
                    if newValue != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            documentViewModel.clearScrollRequest()
                        }
                    }
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            if appViewModel.isFindBarVisible, documentViewModel.hasDocument {
                FindReplaceBar(
                    viewModel: findReplaceViewModel,
                    isRawMode: documentViewModel.displayMode == .raw,
                    onFindNext: { performFindNext() },
                    onFindPrevious: { performFindPrevious() },
                    onReplace: { performReplace() },
                    onReplaceAll: { performReplaceAll() },
                    onClose: { closeFindBar() }
                )
                .padding(.trailing, 16)
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: appViewModel.isFindBarVisible)
        .onChange(of: findReplaceViewModel.searchText) { _, _ in performSearch() }
        .onChange(of: findReplaceViewModel.isCaseSensitive) { _, _ in performSearch() }
        .onChange(of: findReplaceViewModel.isWholeWord) { _, _ in performSearch() }
        .onChange(of: findReplaceViewModel.isRegularExpression) { _, _ in performSearch() }
        .onReceive(NotificationCenter.default.publisher(for: .findInDocument)) { _ in openFindBar() }
        .onReceive(NotificationCenter.default.publisher(for: .findNext)) { _ in performFindNext() }
        .onReceive(NotificationCenter.default.publisher(for: .findPrevious)) { _ in performFindPrevious() }
        .onReceive(NotificationCenter.default.publisher(for: .findAndReplace)) { _ in openFindAndReplace() }
    }
}
