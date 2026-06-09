import SwiftUI
import MarkdownReaderKit

/// 错误提示视图
struct ErrorView: View {
    let icon: String
    let message: String
    @Environment(\.themeColors) private var themeColors

    init(icon: String = "exclamationmark.triangle", message: String) {
        self.icon = icon
        self.message = message
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundStyle(themeColors.fgMuted)

            Text(message)
                .font(.body)
                .foregroundStyle(themeColors.fgSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
