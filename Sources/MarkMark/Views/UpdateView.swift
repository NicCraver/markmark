import SwiftUI
import MarkdownReaderKit

/// 自动更新弹窗视图
/// 显示版本信息、release notes、下载进度，提供跳过/稍后/下载/安装操作
struct UpdateView: View {

    @Environment(\.language) private var language
    @Bindable var viewModel: UpdateViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerSection

            switch viewModel.checkState {
            case .updateAvailable(let release):
                releaseContent(release: release)
            case .upToDate:
                upToDateContent
            case .error(let message):
                errorContent(message: message)
            case .checking:
                checkingContent
            default:
                EmptyView()
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    // MARK: - 头部

    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: headerIcon)
                .font(.system(size: 32))
                .foregroundStyle(headerColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.tr(.updateAvailableTitle, language: language))
                    .font(.headline)
                if let version = viewModel.checkState.availableVersion {
                    Text(L10n.tr(.updateAvailableVersion, language: language, args: ["version": version]))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var headerIcon: String {
        switch viewModel.installMode {
        case .zip: return "arrow.down.circle.fill"
        case .dmg: return "arrow.down.circle"
        }
    }

    private var headerColor: Color {
        switch viewModel.installMode {
        case .zip: return .blue
        case .dmg: return .orange
        }
    }

    // MARK: - 有更新

    private func releaseContent(release: GitHubRelease) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 安装模式提示
            installModeHint

            // DMG 手动安装：使用本地化说明，避免展示 GitHub Release 中的旧版 Markdown Reader 文案
            if viewModel.installMode == .dmg {
                releaseNotesSection(
                    title: L10n.tr(.updateInstallInstructionsTitle, language: language),
                    body: L10n.tr(.updateManualInstallInstructions, language: language),
                    scrollHeight: 168
                )
            }

            let changelog = ReleaseNotesFormatter.changelog(from: release.body)
            if !changelog.isEmpty {
                let changelogLines = changelog.components(separatedBy: "\n").count
                releaseNotesSection(
                    title: L10n.tr(.updateReleaseNotesTitle, language: language),
                    body: changelog,
                    scrollHeight: changelogLines > 3 ? 96 : nil
                )
            } else if viewModel.installMode == .zip, !release.body.isEmpty {
                releaseNotesSection(
                    title: nil,
                    body: ReleaseNotesFormatter.sanitize(release.body)
                )
            }

            // 下载进度
            if let progress = viewModel.downloadProgress, progress < 1.0 {
                ProgressView(value: progress) {
                    Text(L10n.tr(.updateDownloading, language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } currentValueLabel: {
                    Text("\(Int(progress * 100))%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .progressViewStyle(.linear)
            }

            // ZIP 下载完成，等待安装
            if viewModel.installMode == .zip && viewModel.downloadProgress == 1.0 && !viewModel.isInstalling {
                Text(L10n.tr(.updateDownloadComplete, language: language))
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            // 正在安装
            if viewModel.isInstalling {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(L10n.tr(.updateInstalling, language: language))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 按钮
            actionButtons(release: release)
        }
    }

    /// scrollHeight 为 nil 时按内容高度自适应；有值时固定高度并启用纵向滚动
    private func releaseNotesSection(
        title: String?,
        body: String,
        scrollHeight: CGFloat? = 160
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }

            Group {
                if let scrollHeight {
                    ScrollView(.vertical, showsIndicators: true) {
                        notesText(body)
                    }
                    .frame(height: scrollHeight)
                } else {
                    notesText(body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }

    private func notesText(_ body: String) -> some View {
        Text(body)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
    }

    /// 安装模式提示文字
    private var installModeHint: some View {
        HStack(spacing: 6) {
            Image(systemName: viewModel.installMode == .zip ? "bolt.fill" : "exclamationmark.triangle.fill")
                .font(.caption2)
            Text(viewModel.installMode == .zip
                 ? L10n.tr(.updateModeAuto, language: language)
                 : L10n.tr(.updateModeManual, language: language))
                .font(.caption2)
        }
        .foregroundStyle(viewModel.installMode == .zip ? .blue : .orange)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            (viewModel.installMode == .zip ? Color.blue : Color.orange).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 4)
        )
    }

    private func actionButtons(release: GitHubRelease) -> some View {
        HStack {
            // 下载中或安装中：取消/跳过按钮
            if viewModel.downloadProgress != nil && (viewModel.downloadProgress ?? 0) < 1.0 {
                Button(L10n.tr(.updateCancel, language: language)) {
                    viewModel.cancelDownload()
                }
                Spacer()
            } else if viewModel.isInstalling {
                // 安装中：无操作
                Spacer()
            } else if viewModel.installMode == .zip && viewModel.downloadProgress == 1.0 {
                // ZIP 下载完成：安装并重启
                Button(L10n.tr(.updateLater, language: language)) {
                    viewModel.remindLater()
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.tr(.updateInstallAndRestart, language: language)) {
                    viewModel.installAndRestart()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            } else {
                // 未下载：跳过 + 稍后 + 下载
                Button(L10n.tr(.updateSkipVersion, language: language)) {
                    viewModel.skipVersion()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Button(L10n.tr(.updateLater, language: language)) {
                    viewModel.remindLater()
                }
                .keyboardShortcut(.cancelAction)

                Button(L10n.tr(.updateDownload, language: language)) {
                    viewModel.downloadAndInstall()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - 已是最新

    private var upToDateContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(L10n.tr(.updateUpToDate, language: language))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(L10n.tr(.confirm, language: language)) {
                    viewModel.isShowingUpdateSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    // MARK: - 检查中

    private var checkingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text(L10n.tr(.updateChecking, language: language))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - 错误

    private func errorContent(message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr(.updateError, language: language))
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()
                Button(L10n.tr(.confirm, language: language)) {
                    viewModel.isShowingUpdateSheet = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
    }
}

// MARK: - Release Notes 格式化

/// 从 GitHub Release body 中提取更新说明，并替换遗留产品名
private enum ReleaseNotesFormatter {
    private static let installSectionHeaders = [
        "## 安装说明",
        "## 安裝說明",
        "## Installation",
    ]

    static func sanitize(_ body: String) -> String {
        body
            .replacingOccurrences(of: "Markdown Reader", with: "MarkMark")
            .replacingOccurrences(of: "MarkdownReader.app", with: "MarkMark.app")
            .replacingOccurrences(of: "MarkdownReader", with: "MarkMark")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 去掉 Release 模板中的安装说明，仅保留 changelog
    static func changelog(from body: String) -> String {
        let text = sanitize(body)
        guard !text.isEmpty else { return "" }

        if let separator = text.range(of: "\n---\n") {
            return String(text[separator.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if installSectionHeaders.contains(where: { text.hasPrefix($0) }) {
            return ""
        }

        return text
    }
}
