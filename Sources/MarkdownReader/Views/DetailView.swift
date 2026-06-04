import SwiftUI

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

    /// Markdown 内容区 NSScrollView 引用，用于大纲导航滚动
    @State private var markdownScrollViewRef = MarkdownScrollViewRef()

    /// 刷新确认弹窗状态
    @State private var showReloadAlert = false
    @State private var dontRemindAgain = false

    var body: some View {
        VStack(spacing: 0) {
            titleBar

            Rectangle().fill(themeColors.border).frame(height: 1)

            // 内容区域
            contentArea
        }
        .background(themeColors.surface, in: .rect(
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

            // 渲染 / 编辑模式切换
            if documentViewModel.hasDocument {
                Picker("", selection: Binding(
                    get: { documentViewModel.displayMode },
                    set: { documentViewModel.switchDisplayMode($0) }
                )) {
                    Text(L10n.tr(.displayModeRendered, language: language)).tag(DisplayMode.rendered)
                    Text(L10n.tr(.displayModeRaw, language: language)).tag(DisplayMode.raw)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
                .padding(.trailing, 8)
            }

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
                .padding(.trailing, 4)
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
                .padding(.trailing, 8)
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
            .padding(.trailing, 12)
        }
        .frame(height: 50)
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
            }
        )
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
            // Raw 模式视图 — 始终保持存活，避免 NSTextView 被销毁导致 undo 历史丢失
            RawMarkdownView(
                content: Binding(
                    get: { documentViewModel.content },
                    set: { documentViewModel.content = $0 }
                ),
                fontSize: settings.sourceFontPointSize,
                contentPadding: settings.contentPaddingPoints,
                scrollToLine: documentViewModel.scrollToLineRequest,
                fileURL: documentViewModel.currentFileURL,
                isActive: documentViewModel.displayMode == .raw
            )
            .opacity(documentViewModel.displayMode == .raw ? 1 : 0)
            .allowsHitTesting(documentViewModel.displayMode == .raw)
            .onChange(of: documentViewModel.scrollToLineRequest) { _, newValue in
                if newValue != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        documentViewModel.clearScrollRequest()
                    }
                }
            }

            // 渲染模式视图 — 仅在渲染模式下显示
            if documentViewModel.displayMode == .rendered {
                EquatableRenderedMarkdownView(
                    content: documentViewModel.content,
                    fileURL: documentViewModel.currentFileURL,
                    contentPadding: settings.contentPaddingPoints,
                    scrollToLine: documentViewModel.scrollToLineRequest,
                    scrollViewRef: markdownScrollViewRef
                )
                .onChange(of: documentViewModel.scrollToLineRequest) { _, newValue in
                    if newValue != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            documentViewModel.clearScrollRequest()
                        }
                    }
                }
            }
        }
    }
}
