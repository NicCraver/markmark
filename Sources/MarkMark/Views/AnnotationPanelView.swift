import SwiftUI
import MarkdownReaderKit

/// 标注列表面板：列出当前文档的全部 CriticMarkup 标注，
/// 分「本次新增 / 历史标注」两组，支持勾选后复制所选片段。
///
/// 数据模型：文档是事实源——列表每次渲染从 `content` 实时解析；
/// 会话记录（DocumentViewModel.sessionAnnotations）仅用于把解析结果归入「本次新增」组，
/// 匹配不回文档的记录显示为「已失效」（如标注已被应用/放弃或文件被外部修改）。
struct AnnotationPanelView: View {
    let documentViewModel: DocumentViewModel
    /// 复制成功回调（由 DetailView 显示「已复制」提示）
    var onCopied: (() -> Void)?
    @Environment(\.themeColors) private var themeColors
    @Environment(\.language) private var language

    /// 选中的条目 id（id 基于标注内容生成，与位置无关，文档无关编辑不影响选中态）
    @State private var selectedIDs: Set<String> = []
    /// 已按「本次新增」初始化过选中态的文件，避免切回文件时重置用户的勾选
    @State private var initializedFile: URL?

    // MARK: - 数据

    /// 面板单行条目
    private struct Item: Identifiable {
        let id: String
        let kind: CriticMarkup.Annotation.Kind
        let summary: String
        let detail: String?
        let line: Int
        let position: Int
        let isNew: Bool
        let isStale: Bool
    }

    private struct PanelData {
        var newItems: [Item] = []
        var historyItems: [Item] = []
        var annotationsByID: [String: CriticMarkup.Annotation] = [:]

        var allValidIDs: Set<String> {
            Set((newItems + historyItems).filter { !$0.isStale }.map(\.id))
        }
        var newValidIDs: Set<String> {
            Set(newItems.filter { !$0.isStale }.map(\.id))
        }
        var isEmpty: Bool { newItems.isEmpty && historyItems.isEmpty }
    }

    /// 从当前文档解析标注并与会话记录配对
    private var panelData: PanelData {
        let content = documentViewModel.content
        let annotations = CriticMarkup.parseAnnotations(in: content)
        let records = documentViewModel.currentSessionAnnotations

        // 基于内容生成稳定 id：同内容多次出现时追加序号
        var idCounts: [String: Int] = [:]
        func makeID(_ ann: CriticMarkup.Annotation) -> String {
            let base = "\(ann.kind.rawValue)|\(ann.text)|\(ann.payload ?? "")"
            let n = idCounts[base, default: 0]
            idCounts[base] = n + 1
            return "\(base)|\(n)"
        }

        // 会话记录 → 解析结果配对（按 kind/text/payload，每条解析结果只消费一次）
        var consumed = Set<Int>()
        var newIndices = Set<Int>()
        var staleRecords: [DocumentViewModel.SessionAnnotationRecord] = []
        for record in records {
            if let idx = annotations.indices.first(where: { i in
                !consumed.contains(i)
                    && annotations[i].kind == record.kind
                    && annotations[i].text == record.text
                    && (annotations[i].payload ?? "") == (record.payload ?? "")
            }) {
                consumed.insert(idx)
                newIndices.insert(idx)
            } else {
                staleRecords.append(record)
            }
        }

        var data = PanelData()
        let sourceStart = content.startIndex
        for (idx, ann) in annotations.enumerated() {
            let id = makeID(ann)
            data.annotationsByID[id] = ann
            let item = Item(
                id: id,
                kind: ann.kind,
                summary: ann.text.isEmpty ? (ann.payload ?? "") : ann.text,
                detail: ann.payload,
                line: ann.line,
                position: content.distance(from: sourceStart, to: ann.range.lowerBound),
                isNew: newIndices.contains(idx),
                isStale: false
            )
            if item.isNew {
                data.newItems.append(item)
            } else {
                data.historyItems.append(item)
            }
        }
        // 失效的会话记录追加在「本次新增」组尾部（置灰，不可勾选）
        for (i, record) in staleRecords.enumerated() {
            data.newItems.append(Item(
                id: "stale|\(i)|\(record.text)",
                kind: record.kind,
                summary: record.text.isEmpty ? (record.payload ?? "") : record.text,
                detail: record.payload,
                line: 0,
                position: Int.max,
                isNew: true,
                isStale: true
            ))
        }
        return data
    }

    // MARK: - 视图

    var body: some View {
        let data = panelData

        VStack(alignment: .leading, spacing: 0) {
            header

            Divider().background(themeColors.border)

            if data.isEmpty {
                emptyState
            } else {
                list(data)

                Divider().background(themeColors.border)

                footer(data)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeColors.surface)
        .onAppear { initializeSelectionIfNeeded(data) }
        .onChange(of: documentViewModel.currentFileURL) { _, _ in
            initializedFile = nil
            initializeSelectionIfNeeded(panelData)
        }
        .onChange(of: data.newValidIDs) { old, new in
            // 面板打开期间新加的标注自动勾选
            selectedIDs.formUnion(new.subtracting(old))
            // 清掉已不存在的 id
            selectedIDs.formIntersection(data.allValidIDs)
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "highlighter")
                .font(.system(size: 12))
                .foregroundStyle(themeColors.fgMuted)
            Text(L10n.tr(.titleBarAnnotationPanel, language: language))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(themeColors.fgMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "highlighter")
                .font(.system(size: 20))
                .foregroundStyle(themeColors.fgMuted)
            Text(L10n.tr(.annotationEmpty, language: language))
                .font(.system(size: 11))
                .foregroundStyle(themeColors.fgMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func list(_ data: PanelData) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !data.newItems.isEmpty {
                    groupHeader(L10n.tr(.annotationGroupNew, language: language))
                    ForEach(data.newItems) { row($0) }
                }
                if !data.historyItems.isEmpty {
                    groupHeader(L10n.tr(.annotationGroupHistory, language: language))
                    ForEach(data.historyItems) { row($0) }
                }
            }
            .padding(.vertical, 4)
            .background(OverlayScrollerHelper())
        }
        .scrollIndicators(.automatic)
    }

    private func groupHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.5)
            .foregroundStyle(themeColors.fgMuted)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private func row(_ item: Item) -> some View {
        HStack(alignment: .top, spacing: 6) {
            // 勾选框（失效条目不可勾选）
            if item.isStale {
                Image(systemName: "square")
                    .font(.system(size: 12))
                    .foregroundStyle(themeColors.fgMuted.opacity(0.4))
            } else {
                Button {
                    if selectedIDs.contains(item.id) {
                        selectedIDs.remove(item.id)
                    } else {
                        selectedIDs.insert(item.id)
                    }
                } label: {
                    Image(systemName: selectedIDs.contains(item.id) ? "checkmark.square.fill" : "square")
                        .font(.system(size: 12))
                        .foregroundStyle(selectedIDs.contains(item.id) ? themeColors.accent : themeColors.fgMuted)
                }
                .buttonStyle(.plain)
            }

            // 内容（点击跳转到标注位置）
            Button {
                if !item.isStale, item.line > 0 {
                    documentViewModel.requestScrollToLine(item.line)
                }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: icon(for: item.kind))
                            .font(.system(size: 9))
                            .foregroundStyle(item.isStale ? themeColors.fgMuted.opacity(0.5) : color(for: item.kind))
                        Text(item.summary)
                            .font(.system(size: 11.5))
                            .foregroundStyle(item.isStale ? themeColors.fgMuted.opacity(0.6) : themeColors.ink)
                            .lineLimit(2)
                        if item.isStale {
                            Text(L10n.tr(.annotationStale, language: language))
                                .font(.system(size: 9))
                                .foregroundStyle(themeColors.fgMuted)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(themeColors.bgMuted))
                        }
                    }
                    if let detail = item.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(size: 10.5))
                            .foregroundStyle(item.isStale ? themeColors.fgMuted.opacity(0.5) : themeColors.fgSecondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private func footer(_ data: PanelData) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Button(L10n.tr(.annotationSelectAll, language: language)) {
                    selectedIDs = data.allValidIDs
                }
                .controlSize(.small)
                Button(L10n.tr(.annotationSelectNew, language: language)) {
                    selectedIDs = data.newValidIDs
                }
                .controlSize(.small)
                .disabled(data.newValidIDs.isEmpty)
                Spacer()
            }

            Button {
                copySelectedFragments(data)
            } label: {
                Label(L10n.tr(.annotationCopySelected, language: language), systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .disabled(selectedIDs.intersection(data.allValidIDs).isEmpty)
        }
        .padding(10)
    }

    // MARK: - 行为

    /// 首次显示（或切换文件后）默认勾选「本次新增」
    private func initializeSelectionIfNeeded(_ data: PanelData) {
        guard initializedFile != documentViewModel.currentFileURL else { return }
        initializedFile = documentViewModel.currentFileURL
        selectedIDs = data.newValidIDs
    }

    private func copySelectedFragments(_ data: PanelData) {
        let annotations = selectedIDs.compactMap { data.annotationsByID[$0] }
        guard !annotations.isEmpty else { return }
        let fragments = CriticMarkup.fragments(for: annotations, in: documentViewModel.content)
        // 纯片段，不带 AI 提示头
        let text = CriticMarkup.exportFragments(fragments)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        onCopied?()
    }

    private func icon(for kind: CriticMarkup.Annotation.Kind) -> String {
        switch kind {
        case .addition: return "plus.circle"
        case .deletion: return "minus.circle"
        case .substitution: return "arrow.left.arrow.right.circle"
        case .highlight: return "highlighter"
        case .comment: return "text.bubble"
        }
    }

    private func color(for kind: CriticMarkup.Annotation.Kind) -> Color {
        switch kind {
        case .addition: return .green
        case .deletion: return .red
        case .substitution: return .orange
        case .highlight: return .yellow
        case .comment: return themeColors.accent
        }
    }
}
