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

            // Release notes
            if !release.body.isEmpty {
                ScrollView {
                    Text(release.body)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 160)
                .padding(8)
                .background(.quaternary.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 6))
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
