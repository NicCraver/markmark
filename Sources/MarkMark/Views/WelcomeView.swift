import SwiftUI
import MarkdownReaderKit

/// 空状态占位视图，提示用户打开目录或文件，并列出最近打开的文件
struct WelcomeView: View {
    let appViewModel: AppViewModel
    let settings: SettingsModel
    @Environment(\.language) private var language
    @Environment(\.themeColors) private var themeColors

    /// 最近打开的文件（最多 5 个，仅文件不含目录）
    private var recentFiles: [RecentItem] {
        Array(settings.recentItems.filter { !$0.isDirectory }.prefix(5))
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "folder")
                .font(.system(size: 48))
                .foregroundStyle(themeColors.fgMuted)

            Text(L10n.tr(.welcomeOpenFolder, language: language))
                .font(.title2)
                .foregroundStyle(themeColors.ink)

            Text(L10n.tr(.welcomePressCmdO, language: language))
                .font(.subheadline)
                .foregroundStyle(themeColors.fgSecondary)

            Text(L10n.tr(.welcomeDropHint, language: language))
                .font(.subheadline)
                .foregroundStyle(themeColors.fgMuted)

            HStack(spacing: 10) {
                Button(L10n.tr(.open, language: language)) {
                    OpenPanelHelper.show(language: language)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                // 从剪贴板新建标注：粘贴 Markdown 直接进入标注流程
                Button {
                    NotificationCenter.default.post(name: .newFromClipboard, object: nil)
                } label: {
                    Label(L10n.tr(.newFromClipboard, language: language), systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.top, 8)

            if !recentFiles.isEmpty {
                recentSection
                    .padding(.top, 18)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.tr(.openRecent, language: language))
                .font(.system(size: 11, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.6)
                .foregroundStyle(themeColors.fgMuted)
                .padding(.leading, 10)
                .padding(.bottom, 4)

            ForEach(recentFiles) { item in
                RecentFileRow(item: item, themeColors: themeColors)
            }
        }
        .frame(maxWidth: 420)
    }
}

/// 单行最近文件，hover 高亮，点击打开
private struct RecentFileRow: View {
    let item: RecentItem
    let themeColors: ThemeColors
    @State private var hovering = false

    var body: some View {
        Button {
            NotificationCenter.default.post(name: .openFile, object: item.url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .font(.system(size: 14))
                    .foregroundStyle(themeColors.accent)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.url.lastPathComponent)
                        .font(.system(size: 13.5, weight: .medium))
                        .foregroundStyle(themeColors.ink)
                        .lineLimit(1)
                    Text(item.url.deletingLastPathComponent().path)
                        .font(.system(size: 11))
                        .foregroundStyle(themeColors.fgMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovering ? themeColors.accentSoft : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(item.url.path)
    }
}
