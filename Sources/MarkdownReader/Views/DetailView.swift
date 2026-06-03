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
                    NotificationCenter.default.post(name: .openPanel, object: nil)
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                        .foregroundStyle(themeColors.fgSecondary)
                }
                .buttonStyle(.plain)
                .help(L10n.tr(.titleBarOpen, language: language))
                .padding(.leading, 8)
            }

            // 文件绝对路径（左对齐，仅在有文档时显示）
            if documentViewModel.hasDocument, let path = documentViewModel.currentFileURL?.path {
                Text(path)
                    .font(.system(size: 12))
                    .foregroundStyle(themeColors.fgMuted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.leading, 12)
            }

            Spacer()

            // 渲染 / 原始模式切换
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
    }

    // MARK: - 内容区

    @ViewBuilder
    private var contentArea: some View {
        if appViewModel.rootDirectory == nil && !appViewModel.isSingleFileMode {
            WelcomeView(appViewModel: appViewModel)
        } else if let error = documentViewModel.fileError {
            ErrorView(
                icon: "exclamationmark.triangle",
                message: error.localizedDescription
            )
        } else if documentViewModel.isLoading && !documentViewModel.hasDocument {
            // 仅在首次加载（无已有文档）时显示进度指示器
            // 文件切换时 hasDocument 仍为 true（旧文件 URL 未清空），
            // 保持文档内容视图存活，防止 NSTextView 被释放导致 undo 崩溃
            ProgressView()
                .tint(themeColors.fgSecondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if documentViewModel.hasDocument {
            documentContentWithOutline
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
