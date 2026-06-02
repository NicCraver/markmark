import SwiftUI

/// 项目状态面板，显示 Git 状态、变更文件和提交操作
struct ProjectStatusView: View {
    @Bindable var gitViewModel: GitViewModel
    let appViewModel: AppViewModel
    @Environment(\.language) private var language
    @Environment(\.themeColors) private var themeColors

    /// 是否展开变更文件列表
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // 成功消息 toast
            successToast

            Rectangle().fill(themeColors.border).frame(height: 1)

            // 主状态栏
            statusBar
        }
    }

    // MARK: - 成功消息 Toast

    @ViewBuilder
    private var successToast: some View {
        if let message = gitViewModel.successMessage {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(themeColors.success)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(themeColors.ink)

                Spacer()

                Button {
                    gitViewModel.dismissSuccess()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(themeColors.fgSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(themeColors.success.opacity(0.08))
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: 0) {
            // 第一行：分支信息 + 操作
            HStack(spacing: 12) {
                // 分支标识
                branchBadge

                // 变更计数
                changeCountBadge

                Spacer()

                // Commit + Push
                commitPushArea
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // 第二行：变更文件列表（可展开）
            if isExpanded {
                changeFileList
            }
        }
        .background(themeColors.bgElevated)
    }

    // MARK: - 分支标识

    private var branchBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 11))
            Text(gitViewModel.branchName)
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(themeColors.fgSecondary)
    }

    // MARK: - 变更计数

    private var changeCountBadge: some View {
        Group {
            if gitViewModel.hasChanges {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.badge.gearshape")
                            .font(.system(size: 11))
                        Text(L10n.tr(.gitChangesCount, language: language, args: ["n": "\(gitViewModel.totalChangeCount)"]))
                            .font(.system(size: 12))
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundStyle(themeColors.accent)
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 11))
                    Text(L10n.tr(.gitNoChanges, language: language))
                        .font(.system(size: 12))
                }
                .foregroundStyle(themeColors.fgSecondary)
            }
        }
    }

    // MARK: - Commit + Push 区域

    private var commitPushArea: some View {
        HStack(spacing: 8) {
            // Commit 消息输入框
            TextField(L10n.tr(.gitCommitMessage, language: language), text: $gitViewModel.commitMessage)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12))
                .frame(width: 180)

            // 提交并推送按钮
            Button {
                gitViewModel.commitAndPush(directory: appViewModel.rootDirectory)
            } label: {
                HStack(spacing: 4) {
                    if gitViewModel.isCommitting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up.circle")
                            .font(.system(size: 12))
                    }
                    Text(gitViewModel.isCommitting ? L10n.tr(.gitPushing, language: language) : L10n.tr(.gitCommitAndPush, language: language))
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(
                gitViewModel.isCommitting
                || gitViewModel.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
    }

    // MARK: - 变更文件列表

    private var changeFileList: some View {
        VStack(spacing: 0) {
            Rectangle().fill(themeColors.border).frame(height: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    // 暂存区文件
                    if let staged = gitViewModel.gitStatus?.stagedFiles, !staged.isEmpty {
                        sectionHeader(L10n.tr(.gitStaged, language: language), count: staged.count)
                        ForEach(staged, id: \.path) { change in
                            fileChangeRow(change, prefix: "staged")
                        }
                    }

                    // 工作区变更文件
                    if let unstaged = gitViewModel.gitStatus?.unstagedFiles, !unstaged.isEmpty {
                        sectionHeader(L10n.tr(.gitModified, language: language), count: unstaged.count)
                        ForEach(unstaged, id: \.path) { change in
                            fileChangeRow(change, prefix: "unstaged")
                        }
                    }

                    // 未跟踪文件
                    if let untracked = gitViewModel.gitStatus?.untrackedFiles, !untracked.isEmpty {
                        sectionHeader(L10n.tr(.gitUntracked, language: language), count: untracked.count)
                        ForEach(untracked, id: \.self) { path in
                            HStack(spacing: 6) {
                                Text("?")
                                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                                    .foregroundStyle(themeColors.fgMuted)
                                    .frame(width: 14)
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 11))
                                    .foregroundStyle(themeColors.fgSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 2)
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 150)
        }
    }

    // MARK: - 辅助视图

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(themeColors.fgMuted)
            Text("(\(count))")
                .font(.system(size: 10))
                .foregroundStyle(themeColors.fgMuted)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 2)
    }

    private func fileChangeRow(_ change: GitService.FileChange, prefix: String) -> some View {
        HStack(spacing: 6) {
            Text(change.status.rawValue)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(statusColor(change.status))
                .frame(width: 14)
            Text(URL(fileURLWithPath: change.path).lastPathComponent)
                .font(.system(size: 11))
                .foregroundStyle(themeColors.ink)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
        .id("\(prefix)-\(change.path)")
    }

    private func statusColor(_ status: GitService.ChangeStatus) -> Color {
        switch status {
        case .added: return themeColors.success
        case .modified: return themeColors.accent
        case .deleted: return themeColors.danger
        case .renamed: return themeColors.accent
        case .copied: return themeColors.accent
        case .unmerged: return themeColors.danger
        case .unknown: return themeColors.fgSecondary
        }
    }
}
