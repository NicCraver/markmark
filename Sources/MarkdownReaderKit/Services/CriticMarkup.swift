import Foundation

/// CriticMarkup 支持：在 Markdown 源码中表达审阅意见（增/删/改/评论/高亮），
/// 既能在渲染视图中样式化显示，也能一键复制给 AI 进行修订。
///
/// 语法参考 <http://criticmarkup.com>：
/// - 增加 Addition:     `{++ ... ++}`
/// - 删除 Deletion:     `{-- ... --}`
/// - 替换 Substitution: `{~~ old ~> new ~~}`
/// - 评论 Comment:      `{>> ... <<}`
/// - 高亮 Highlight:    `{== ... ==}`
public enum CriticMarkup {

    /// 一次标注动作。
    public enum Operation: Equatable {
        case delete
        case highlight
        case comment(String)   // 高亮选区并附加评论
        case replace(String)   // 用新文本替换选区
        case insert(String)    // 在选区之后插入新文本
    }

    // MARK: - 定位

    /// 在 `source` 中定位 `selectedText`，在多处出现时选取最接近 `nearLine`（1 基）的一处。
    /// 找不到或选区为空返回 nil。
    public static func locateRange(in source: String, selectedText: String, nearLine: Int) -> Range<String.Index>? {
        guard !selectedText.isEmpty else { return nil }

        var ranges: [Range<String.Index>] = []
        var searchStart = source.startIndex
        while searchStart < source.endIndex,
              let r = source.range(of: selectedText, range: searchStart..<source.endIndex) {
            ranges.append(r)
            // 非重叠搜索：从本次匹配末尾继续
            searchStart = r.upperBound > r.lowerBound ? r.upperBound : source.index(after: r.lowerBound)
        }
        guard !ranges.isEmpty else { return nil }

        var best = ranges[0]
        var bestDistance = Int.max
        for r in ranges {
            let line = source[source.startIndex..<r.lowerBound].reduce(into: 1) { acc, ch in
                if ch == "\n" { acc += 1 }
            }
            let distance = abs(line - nearLine)
            if distance < bestDistance {
                bestDistance = distance
                best = r
            }
        }
        return best
    }

    // MARK: - 应用标注

    /// 在源码中定位选区并写入对应 CriticMarkup。找不到选区时返回 nil。
    public static func apply(_ op: Operation, to source: String, selectedText: String, nearLine: Int) -> String? {
        guard let range = locateRange(in: source, selectedText: selectedText, nearLine: nearLine) else {
            return nil
        }
        let selected = String(source[range])
        var result = source
        result.replaceSubrange(range, with: replacement(for: op, selected: selected))
        return result
    }

    private static func replacement(for op: Operation, selected: String) -> String {
        switch op {
        case .delete:
            return "{--\(selected)--}"
        case .highlight:
            return "{==\(selected)==}"
        case .comment(let c):
            return "{==\(selected)==}{>>\(c)<<}"
        case .replace(let new):
            return "{~~\(selected)~>\(new)~~}"
        case .insert(let new):
            return "\(selected){++\(new)++}"
        }
    }

    // MARK: - 编辑 / 删除评论

    /// 编辑已有评论：定位最接近 `nearLine` 的 `{>>oldComment<<}` 并替换其内容。
    public static func editComment(in source: String, oldComment: String, newComment: String, nearLine: Int) -> String? {
        let marker = "{>>\(oldComment)<<}"
        guard let range = locateRange(in: source, selectedText: marker, nearLine: nearLine) else { return nil }
        var result = source
        result.replaceSubrange(range, with: "{>>\(newComment)<<}")
        return result
    }

    /// 删除已有评论：定位 `{>>comment<<}` 并移除；
    /// 若其紧邻前缀是配对的 `{==X==}` 高亮（评论创建时一并添加），则连同高亮还原为原文 `X`。
    public static func deleteComment(in source: String, comment: String, nearLine: Int) -> String? {
        let marker = "{>>\(comment)<<}"
        guard let range = locateRange(in: source, selectedText: marker, nearLine: nearLine) else { return nil }
        var result = source

        let before = result[result.startIndex..<range.lowerBound]
        if let hl = before.range(of: #"\{==[\s\S]*?==\}$"#, options: .regularExpression) {
            // {==X==}{>>comment<<} → X
            let highlight = String(result[hl])
            let inner = String(highlight.dropFirst(3).dropLast(3))   // 去掉 {== 与 ==}
            result.replaceSubrange(hl.lowerBound..<range.upperBound, with: inner)
        } else {
            result.replaceSubrange(range, with: "")
        }
        return result
    }

    // MARK: - 接受 / 拒绝 / 检测

    /// 接受全部修改：增→保留、删→移除、替换→新文本、高亮→保留内容、评论→移除。
    public static func accepting(_ text: String) -> String {
        var s = text
        s = regexReplace(s, #"\{~~([\s\S]*?)~>([\s\S]*?)~~\}"#, template: "$2")
        s = regexReplace(s, #"\{\+\+([\s\S]*?)\+\+\}"#, template: "$1")
        s = regexReplace(s, #"\{--([\s\S]*?)--\}"#, template: "")
        s = regexReplace(s, #"\{==([\s\S]*?)==\}"#, template: "$1")
        s = regexReplace(s, #"\{>>([\s\S]*?)<<\}"#, template: "")
        return s
    }

    /// 拒绝全部修改，恢复原文：增→移除、删→保留、替换→旧文本、高亮→保留内容、评论→移除。
    public static func rejecting(_ text: String) -> String {
        var s = text
        s = regexReplace(s, #"\{~~([\s\S]*?)~>([\s\S]*?)~~\}"#, template: "$1")
        s = regexReplace(s, #"\{\+\+([\s\S]*?)\+\+\}"#, template: "")
        s = regexReplace(s, #"\{--([\s\S]*?)--\}"#, template: "$1")
        s = regexReplace(s, #"\{==([\s\S]*?)==\}"#, template: "$1")
        s = regexReplace(s, #"\{>>([\s\S]*?)<<\}"#, template: "")
        return s
    }

    /// 文本中是否包含任何 CriticMarkup 标注。
    public static func hasMarkup(_ text: String) -> Bool {
        for pattern in [#"\{\+\+[\s\S]*?\+\+\}"#, #"\{--[\s\S]*?--\}"#,
                        #"\{~~[\s\S]*?~~\}"#, #"\{==[\s\S]*?==\}"#, #"\{>>[\s\S]*?<<\}"#] {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - 导出给 AI

    /// 默认引导提示词：解释 CriticMarkup 语法并要求 AI 据此修订后返回。
    public static let defaultAIPrompt = """
    下面是一份带有 CriticMarkup 审阅标注的 Markdown 文档。请理解我的标注并据此修订，然后返回修订后的完整 Markdown（去除标注标记）。

    CriticMarkup 语法说明：
    - {++ 新增内容 ++}        表示需要新增
    - {-- 删除内容 --}        表示需要删除
    - {~~ 旧内容 ~> 新内容 ~~} 表示需要替换
    - {>> 评论 <<}            表示我的评论/疑问，请据此调整
    - {== 高亮内容 ==}        表示我重点关注的部分

    请逐条落实上述标注，并在必要处说明你的修改理由。

    ---
    """

    /// 生成可直接粘贴给 AI 的内容：引导提示词 + 带标注的源码。
    public static func exportForAI(_ markedSource: String, prompt: String? = nil) -> String {
        let header = prompt ?? defaultAIPrompt
        return header + "\n\n" + markedSource + "\n"
    }

    // MARK: - 渲染为 HTML

    /// 将 CriticMarkup 标注转换为带样式 class 的 HTML 片段。
    /// 在 Markdown 解析前调用，使内部 Markdown 仍可正常渲染。
    public static func renderToHTML(_ text: String) -> String {
        var s = text
        // 顺序：先替换（含 ~> ），再增、删、高亮，最后评论（需转义 title）
        s = regexReplace(s, #"\{~~([\s\S]*?)~>([\s\S]*?)~~\}"#,
                         template: "<del class=\"critic critic-del\">$1</del><ins class=\"critic critic-add\">$2</ins>")
        s = regexReplace(s, #"\{\+\+([\s\S]*?)\+\+\}"#,
                         template: "<ins class=\"critic critic-add\">$1</ins>")
        s = regexReplace(s, #"\{--([\s\S]*?)--\}"#,
                         template: "<del class=\"critic critic-del\">$1</del>")
        s = regexReplace(s, #"\{==([\s\S]*?)==\}"#,
                         template: "<mark class=\"critic critic-mark\">$1</mark>")
        s = renderComments(s)
        return s
    }

    private static func renderComments(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\{>>([\s\S]*?)<<\}"#) else { return text }
        var result = text
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: result),
                  let commentRange = Range(match.range(at: 1), in: result) else { continue }
            let comment = attributeEscaped(String(result[commentRange]))
            let replacement = "<span class=\"critic critic-comment\" title=\"\(comment)\" data-comment=\"\(comment)\">\u{1F4AC}</span>"
            result.replaceSubrange(range, with: replacement)
        }
        return result
    }

    // MARK: - 工具

    private static func regexReplace(_ text: String, _ pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    private static func attributeEscaped(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
