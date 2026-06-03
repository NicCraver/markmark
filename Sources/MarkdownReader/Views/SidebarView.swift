import SwiftUI

/// 左侧 Sidebar 目录树视图
struct SidebarView: View {
    let fileTreeViewModel: FileTreeViewModel
    let appViewModel: AppViewModel
    @Environment(\.language) private var language
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        VStack(spacing: 0) {
            // 顶部区域：自定义红绿灯 + 打开按钮 + Sidebar 隐藏按钮（50px）
            HStack(spacing: 0) {
                // 自定义红绿灯按钮
                TrafficLightButtons()
                    .padding(.leading, 12)

                Spacer()

                // 打开按钮（与菜单 Cmd+O 功能一致）
                Button {
                    NotificationCenter.default.post(name: .openPanel, object: nil)
                } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 14))
                        .foregroundStyle(themeColors.fgSecondary)
                }
                .buttonStyle(.plain)
                .help(L10n.tr(.titleBarOpen, language: language))
                .padding(.trailing, 4)

                // Sidebar 隐藏按钮
                Button {
                    appViewModel.toggleSidebar()
                } label: {
                    Image(systemName: "sidebar.leading")
                        .font(.system(size: 14))
                        .foregroundStyle(themeColors.fgSecondary)
                }
                .buttonStyle(.plain)
                .help(L10n.tr(.titleBarToggleSidebar, language: language))
                .padding(.trailing, 8)
            }
            .frame(height: 50)

            if appViewModel.isSingleFileMode {
                singleFileView
            } else if fileTreeViewModel.isLoading {
                ProgressView(L10n.tr(.loading, language: language))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = fileTreeViewModel.errorMessage {
                ErrorView(message: error)
            } else if fileTreeViewModel.nodes.isEmpty {
                emptyDirectoryView
            } else {
                directoryTreeView
            }

            // 底部固定区域：Settings 按钮（参考 Buddy 底部固定设置入口）
            settingsButton
        }
        .background(themeColors.bgSubtle)
    }

    // MARK: - 单文件列表

    private var singleFileView: some View {
        List {
            if let url = appViewModel.singleFileURL {
                Button {
                    fileTreeViewModel.selectedFileURL = url
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 14))
                            .foregroundStyle(themeColors.fgSecondary)
                        Text(url.lastPathComponent)
                            .font(.system(size: 13))
                            .foregroundStyle(themeColors.ink)
                            .lineLimit(1)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    fileTreeViewModel.selectedFileURL == url ? themeColors.accentSoft : Color.clear
                )
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
    }

    // MARK: - 目录树（使用递归 DisclosureGroup 渲染嵌套结构）

    private var directoryTreeView: some View {
        List {
            ForEach(fileTreeViewModel.nodes) { node in
                FileNodeRow(node: node, fileTreeViewModel: fileTreeViewModel)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.automatic)
        .focusable()
        .onMoveCommand { direction in
            switch direction {
            case .up:
                _ = fileTreeViewModel.moveSelection(direction: -1)
            case .down:
                _ = fileTreeViewModel.moveSelection(direction: 1)
            default:
                break
            }
        }
        .onKeyPress(.return) {
            if let url = fileTreeViewModel.selectedFileURL,
               let node = findNode(in: fileTreeViewModel.nodes, url: url) {
                if node.isDirectory {
                    fileTreeViewModel.toggleExpand(url)
                } else {
                    fileTreeViewModel.selectFile(node)
                }
            }
            return .handled
        }
    }

    // MARK: - 空目录提示

    private var emptyDirectoryView: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundStyle(themeColors.fgMuted)
            Text(L10n.tr(.emptyDirectoryMessage, language: language))
                .font(.subheadline)
                .foregroundStyle(themeColors.fgSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 底部设置按钮

    private var settingsButton: some View {
        Button {
            appViewModel.showSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(themeColors.fgSecondary)
                Text(L10n.tr(.sidebarSettingsButton, language: language))
                    .font(.system(size: 13))
                    .foregroundStyle(themeColors.fgSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(L10n.tr(.sidebarSettings, language: language))
    }

    // MARK: - 辅助方法

    private func findNode(in nodes: [FileNode], url: URL) -> FileNode? {
        for node in nodes {
            if node.path == url { return node }
            if node.isDirectory, let children = node.children {
                if let found = findNode(in: children, url: url) {
                    return found
                }
            }
        }
        return nil
    }
}

// MARK: - 递归目录节点视图

/// 支持展开/折叠绑定的递归目录节点视图
struct FileNodeRow: View {
    let node: FileNode
    let fileTreeViewModel: FileTreeViewModel
    @Environment(\.themeColors) private var themeColors

    /// 是否为当前选中项
    private var isSelected: Bool {
        fileTreeViewModel.selectedFileURL == node.path
    }

    /// 自定义选中背景（模仿系统选中样式：左侧留空、圆角、accentSoft）
    @ViewBuilder
    private var selectionBackground: some View {
        if isSelected {
            // 先加圆角，再整体加 padding，确保圆角可见
            themeColors.accentSoft
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.leading, 28)
                .padding(.trailing, 6)
                .padding(.vertical, 2)
        } else {
            Color.clear
        }
    }

    var body: some View {
        if let children = node.children, !children.isEmpty {
            DisclosureGroup(
                isExpanded: Binding(
                    get: { fileTreeViewModel.isExpanded(node.path) },
                    set: { _ in fileTreeViewModel.toggleExpand(node.path) }
                )
            ) {
                ForEach(children) { child in
                    FileNodeRow(node: child, fileTreeViewModel: fileTreeViewModel)
                }
            } label: {
                FileRowView(node: node, fileTreeViewModel: fileTreeViewModel)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // 点击目录标签区域切换展开/折叠
                        fileTreeViewModel.toggleExpand(node.path)
                    }
            }
            .listRowBackground(selectionBackground)
        } else {
            // 文件行使用 Button 确保可靠选中
            Button {
                fileTreeViewModel.selectFile(node)
            } label: {
                FileRowView(node: node, fileTreeViewModel: fileTreeViewModel)
            }
            .buttonStyle(.plain)
            .listRowBackground(selectionBackground)
        }
    }
}
