import SwiftUI

/// 目录树中单个文件/目录行视图
struct FileRowView: View {
    let node: FileNode
    let fileTreeViewModel: FileTreeViewModel
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        HStack(spacing: 6) {
            if node.isDirectory {
                Image(systemName: "folder.fill")
                    .foregroundStyle(themeColors.ink)
                    .frame(width: 16)
            } else {
                Image(systemName: node.isMarkdown ? "doc.text" : "doc")
                    .foregroundStyle(node.isMarkdown ? themeColors.fgSecondary : themeColors.fgMuted)
                    .frame(width: 16)
            }

            Text(node.name)
                .foregroundStyle(node.isMarkdown || node.isDirectory ? themeColors.ink : themeColors.fgSecondary)
                .lineLimit(1)

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
