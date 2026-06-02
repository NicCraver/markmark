import SwiftUI
import UniformTypeIdentifiers

/// 空状态占位视图，提示用户打开目录或文件
struct WelcomeView: View {
    let appViewModel: AppViewModel
    @Environment(\.language) private var language
    @Environment(\.themeColors) private var themeColors

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

            Button(L10n.tr(.open, language: language)) {
                openPanel()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 打开面板，支持选择目录和 .md 文件
    private func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = L10n.tr(.open, language: language)
        panel.allowedContentTypes = [.folder, UTType(filenameExtension: "md")].compactMap { $0 }

        if panel.runModal() == .OK, let url = panel.url {
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)

            if isDir.boolValue {
                appViewModel.openDirectory(url)
            } else {
                appViewModel.openSingleFile(url)
                NotificationCenter.default.post(name: .openFile, object: url)
            }
        }
    }
}
