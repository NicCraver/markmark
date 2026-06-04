import SwiftUI

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
                OpenPanelHelper.show(language: language)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
