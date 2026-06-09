import AppKit

// MARK: - 语法高亮颜色令牌

/// 从 ThemeColors 派生的语法高亮专用颜色
/// 通过 SwiftUI Color → NSColor 转换，供 NSTextView 使用
struct SyntaxColors {
    let heading: NSColor
    let bold: NSColor
    let italic: NSColor
    let codeSpan: NSColor
    let codeBlock: NSColor
    let codeBlockBackground: NSColor
    let link: NSColor
    let image: NSColor
    let blockquote: NSColor
    let listMarker: NSColor
    let horizontalRule: NSColor
    let plain: NSColor
    let comment: NSColor   // HTML 注释等
    let accent: NSColor    // 强调色（任务列表等）

    /// 从主题基础色派生语法高亮颜色
    static func from(
        surface: NSColor,
        ink: NSColor,
        accent: NSColor,
        success: NSColor,
        danger: NSColor,
        isDark: Bool
    ) -> SyntaxColors {
        SyntaxColors(
            heading: accent,
            bold: ink.blended(with: 0.15, of: accent) ?? ink,
            italic: ink.blended(with: 0.10, of: success) ?? ink,
            codeSpan: isDark
                ? NSColor(red: 0.98, green: 0.85, blue: 0.55, alpha: 1.0)  // 暖黄色
                : NSColor(red: 0.78, green: 0.35, blue: 0.10, alpha: 1.0), // 棕橙色
            codeBlock: isDark
                ? NSColor(red: 0.85, green: 0.85, blue: 0.70, alpha: 1.0)  // 淡黄绿
                : NSColor(red: 0.40, green: 0.40, blue: 0.30, alpha: 1.0),
            codeBlockBackground: isDark
                ? surface.blended(with: 0.06, of: ink) ?? surface
                : surface.blended(with: 0.04, of: ink) ?? surface,
            link: accent,
            image: accent.blended(with: 0.3, of: success) ?? accent,
            blockquote: isDark
                ? ink.withAlphaComponent(0.55)
                : ink.withAlphaComponent(0.50),
            listMarker: accent,
            horizontalRule: isDark
                ? ink.withAlphaComponent(0.30)
                : ink.withAlphaComponent(0.25),
            plain: ink,
            comment: isDark
                ? ink.withAlphaComponent(0.40)
                : ink.withAlphaComponent(0.35),
            accent: accent
        )
    }
}

// MARK: - NST颜色混合辅助

extension NSColor {
    /// 将两个颜色按比例混合（fraction 为 other 的比例）
    func blended(with fraction: CGFloat, of other: NSColor) -> NSColor? {
        blended(withFraction: fraction, of: other)
    }
}

// MARK: - Markdown 语法高亮器

/// Markdown 语法高亮器：解析文本并返回需要着色的范围
/// 使用基于正则的解析策略，按优先级处理各语法元素
struct MarkdownSyntaxHighlighter {

    /// 高亮范围结果
    struct HighlightRange {
        let range: NSRange
        let color: NSColor
        var backgroundColor: NSColor? = nil  // 可选背景色（代码块等）
        let isBold: Bool
        let isItalic: Bool
    }

    /// 对整个文本进行语法高亮分析
    static func highlight(_ text: String, colors: SyntaxColors) -> [HighlightRange] {
        var results: [HighlightRange] = []
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        // 已被高优先级规则覆盖的范围追踪
        var covered = CoveredRanges(totalLength: nsString.length)

        // 按优先级从高到低处理
        // 1. 代码块（最高优先级，内部不做其他高亮）
        applyCodeBlocks(nsString, fullRange, colors, &results, &covered)

        // 2. 行内代码
        applyCodeSpans(nsString, fullRange, colors, &results, &covered)

        // 3. HTML 注释
        applyHTMLComments(nsString, fullRange, colors, &results, &covered)

        // 4. 标题
        applyHeadings(nsString, fullRange, colors, &results, &covered)

        // 5. 链接和图片
        applyLinksAndImages(nsString, fullRange, colors, &results, &covered)

        // 6. 加粗+斜体 (***text*** 或 ___text___)
        applyBoldItalic(nsString, fullRange, colors, &results, &covered)

        // 7. 加粗 (**text** 或 __text__)
        applyBold(nsString, fullRange, colors, &results, &covered)

        // 8. 斜体 (*text* 或 _text_)
        applyItalic(nsString, fullRange, colors, &results, &covered)

        // 9. 引用块
        applyBlockquotes(nsString, fullRange, colors, &results, &covered)

        // 10. 列表标记
        applyListMarkers(nsString, fullRange, colors, &results, &covered)

        // 11. 水平线
        applyHorizontalRules(nsString, fullRange, colors, &results, &covered)

        return results
    }

    // MARK: - 已覆盖范围追踪

    /// 追踪哪些字符位置已被高优先级规则覆盖
    /// 避免低优先级规则重复着色
    private class CoveredRanges {
        private var bitmap: [Bool]
        private let length: Int

        init(totalLength: Int) {
            self.length = totalLength
            self.bitmap = [Bool](repeating: false, count: totalLength)
        }

        /// 标记范围为已覆盖
        func cover(_ range: NSRange) {
            guard range.location + range.length <= length else { return }
            for i in range.location..<(range.location + range.length) {
                bitmap[i] = true
            }
        }

        /// 检查范围是否已被完全覆盖
        func isFullyCovered(_ range: NSRange) -> Bool {
            guard range.length > 0 else { return true }
            guard range.location + range.length <= length else { return true }
            for i in range.location..<(range.location + range.length) {
                if !bitmap[i] { return false }
            }
            return true
        }

        /// 检查范围是否部分覆盖
        func isPartiallyCovered(_ range: NSRange) -> Bool {
            guard range.length > 0 else { return false }
            guard range.location + range.length <= length else { return false }
            for i in range.location..<(range.location + range.length) {
                if bitmap[i] { return true }
            }
            return false
        }
    }

    // MARK: - 各语法规则

    /// 代码块 ```...```
    private static func applyCodeBlocks(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        // 匹配 ```lang\n...\n``` 或 ~~~lang\n...\n~~~
        // 捕获组 1: 开头围栏标记, 组 2: 代码内容, 组 3: 结尾围栏标记
        let pattern = "(?m)(^`{3,}|^~{3,})[^\\n]*\\n([\\s\\S]*?)(\\1)[ \\t]*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let matches = regex.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches {
            if covered.isFullyCovered(match.range) { continue }

            // 开头围栏行（```lang）— 从匹配开始到第一个换行
            let openerRange = match.range(at: 1)
            // 计算整行范围：从 opener 开始到换行符
            let newlineSearchStart = openerRange.location
            let newlineSearchLength = min(match.range.length, nsString.length - newlineSearchStart)
            let newlineRange = nsString.rangeOfCharacter(
                from: CharacterSet.newlines,
                options: [],
                range: NSRange(location: newlineSearchStart, length: newlineSearchLength)
            )
            let openerLineRange: NSRange
            if newlineRange.location != NSNotFound && newlineRange.location < match.range.location + match.range.length {
                openerLineRange = NSRange(location: openerRange.location, length: newlineRange.location - openerRange.location)
            } else {
                openerLineRange = openerRange
            }
            if !covered.isFullyCovered(openerLineRange) {
                results.append(HighlightRange(
                    range: openerLineRange,
                    color: colors.accent.withAlphaComponent(0.70),
                    isBold: false,
                    isItalic: false
                ))
                covered.cover(openerLineRange)
            }

            // 代码内容 — 用 codeBlock 色 + 背景
            let contentRange = match.range(at: 2)
            if !covered.isFullyCovered(contentRange) {
                results.append(HighlightRange(
                    range: contentRange,
                    color: colors.codeBlock,
                    backgroundColor: colors.codeBlockBackground,
                    isBold: false,
                    isItalic: false
                ))
                covered.cover(contentRange)
            }

            // 结尾围栏标记 — 用 accent 色
            let closerRange = match.range(at: 3)
            if !covered.isFullyCovered(closerRange) {
                results.append(HighlightRange(
                    range: closerRange,
                    color: colors.accent.withAlphaComponent(0.70),
                    isBold: false,
                    isItalic: false
                ))
                covered.cover(closerRange)
            }
        }
    }

    /// 行内代码 `code`
    private static func applyCodeSpans(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        // 匹配 ``code`` 或 `code`
        let pattern = "(?<!`)(`+)(?!`)(.*?)(?<!`)(\\1)(?!`)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        let matches = regex.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches {
            if covered.isFullyCovered(match.range) { continue }
            results.append(HighlightRange(
                range: match.range,
                color: colors.codeSpan,
                isBold: false,
                isItalic: false
            ))
            covered.cover(match.range)
        }
    }

    /// HTML 注释 <!-- ... -->
    private static func applyHTMLComments(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        let pattern = "<!--[\\s\\S]*?-->"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        let matches = regex.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches {
            if covered.isFullyCovered(match.range) { continue }
            results.append(HighlightRange(
                range: match.range,
                color: colors.comment,
                isBold: false,
                isItalic: false
            ))
            covered.cover(match.range)
        }
    }

    /// 标题 # ~ ######
    private static func applyHeadings(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        let pattern = "^(#{1,6})[ \\t]+(.*)$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        let matches = regex.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches {
            // # 标记部分
            let markerRange = match.range(at: 1)
            if !covered.isFullyCovered(markerRange) {
                results.append(HighlightRange(
                    range: markerRange,
                    color: colors.heading,
                    isBold: true,
                    isItalic: false
                ))
                covered.cover(markerRange)
            }

            // 标题文字部分
            let textRange = match.range(at: 2)
            if !covered.isFullyCovered(textRange) {
                results.append(HighlightRange(
                    range: textRange,
                    color: colors.heading,
                    isBold: true,
                    isItalic: false
                ))
                covered.cover(textRange)
            }
        }
    }

    /// 链接 [text](url) 和图片 ![alt](url)
    private static func applyLinksAndImages(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        // 图片 ![alt](url)
        let imagePattern = "!\\[([^\\]]*)\\]\\(([^)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: imagePattern, options: []) {
            let matches = regex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                if covered.isFullyCovered(match.range) { continue }
                results.append(HighlightRange(
                    range: match.range,
                    color: colors.image,
                    isBold: false,
                    isItalic: false
                ))
                covered.cover(match.range)
            }
        }

        // 链接 [text](url)
        let linkPattern = "(?<!\\!)\\[([^\\]]*)\\]\\(([^)]+)\\)"
        if let regex = try? NSRegularExpression(pattern: linkPattern, options: []) {
            let matches = regex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                if covered.isFullyCovered(match.range) { continue }

                // [text] 部分
                let textRange = match.range(at: 1)
                if !covered.isFullyCovered(textRange) {
                    results.append(HighlightRange(
                        range: textRange,
                        color: colors.link,
                        isBold: false,
                        isItalic: false
                    ))
                    covered.cover(textRange)
                }

                // (url) 部分
                let urlRange = match.range(at: 2)
                if !covered.isFullyCovered(urlRange) {
                    results.append(HighlightRange(
                        range: urlRange,
                        color: colors.link.withAlphaComponent(0.70),
                        isBold: false,
                        isItalic: false
                    ))
                    covered.cover(urlRange)
                }

                // 标记和括号也着色
                // ![ 或 [
                let bracketStart = NSRange(location: match.range.location, length: match.range(at: 1).location - match.range.location)
                if !covered.isFullyCovered(bracketStart) {
                    results.append(HighlightRange(range: bracketStart, color: colors.link.withAlphaComponent(0.60), isBold: false, isItalic: false))
                    covered.cover(bracketStart)
                }
                // ](
                let midBracket = NSRange(location: match.range(at: 1).location + match.range(at: 1).length, length: match.range(at: 2).location - (match.range(at: 1).location + match.range(at: 1).length))
                if !covered.isFullyCovered(midBracket) {
                    results.append(HighlightRange(range: midBracket, color: colors.link.withAlphaComponent(0.60), isBold: false, isItalic: false))
                    covered.cover(midBracket)
                }
                // )
                let endBracket = NSRange(location: match.range(at: 2).location + match.range(at: 2).length, length: 1)
                if endBracket.location + endBracket.length <= nsString.length && !covered.isFullyCovered(endBracket) {
                    results.append(HighlightRange(range: endBracket, color: colors.link.withAlphaComponent(0.60), isBold: false, isItalic: false))
                    covered.cover(endBracket)
                }
            }
        }

        // 引用式链接 [text][ref] / [text][]
        let refLinkPattern = "\\[([^\\]]+)\\]\\[([^\\]]*)\\]"
        if let regex = try? NSRegularExpression(pattern: refLinkPattern, options: []) {
            let matches = regex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                if covered.isFullyCovered(match.range) { continue }
                results.append(HighlightRange(
                    range: match.range,
                    color: colors.link,
                    isBold: false,
                    isItalic: false
                ))
                covered.cover(match.range)
            }
        }

        // 自动链接 <url>
        let autoLinkPattern = "<(https?://[^>]+)>"
        if let regex = try? NSRegularExpression(pattern: autoLinkPattern, options: []) {
            let matches = regex.matches(in: nsString as String, options: [], range: fullRange)
            for match in matches {
                if covered.isFullyCovered(match.range) { continue }
                results.append(HighlightRange(
                    range: match.range,
                    color: colors.link,
                    isBold: false,
                    isItalic: false
                ))
                covered.cover(match.range)
            }
        }
    }

    /// 加粗+斜体 ***text*** 或 ___text___
    private static func applyBoldItalic(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        let pattern = "(\\*{3}|_{3})(?=\\S)(.+?)(?<=\\S)\\1"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        let matches = regex.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches {
            if covered.isFullyCovered(match.range) { continue }
            // 部分覆盖说明匹配跨越了代码块等边界，应跳过整个匹配
            if covered.isPartiallyCovered(match.range) { continue }
            // 标记符号
            let marker1 = match.range(at: 1)
            if !covered.isFullyCovered(marker1) {
                results.append(HighlightRange(range: marker1, color: colors.bold.withAlphaComponent(0.60), isBold: false, isItalic: false))
                covered.cover(marker1)
            }
            // 标记符号（尾部，同长度）
            let marker2 = NSRange(location: match.range.location + match.range.length - marker1.length, length: marker1.length)
            if !covered.isFullyCovered(marker2) {
                results.append(HighlightRange(range: marker2, color: colors.bold.withAlphaComponent(0.60), isBold: false, isItalic: false))
                covered.cover(marker2)
            }
            // 内容
            let contentRange = NSRange(location: marker1.location + marker1.length, length: match.range.length - marker1.length * 2)
            if !covered.isFullyCovered(contentRange) {
                results.append(HighlightRange(range: contentRange, color: colors.bold, isBold: true, isItalic: true))
                covered.cover(contentRange)
            }
        }
    }

    /// 加粗 **text** 或 __text__
    private static func applyBold(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        let pattern = "(\\*{2}|_{2})(?=\\S)(.+?)(?<=\\S)\\1"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return }
        let matches = regex.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches {
            if covered.isFullyCovered(match.range) { continue }
            // 部分覆盖说明匹配跨越了代码块等边界，应跳过整个匹配
            if covered.isPartiallyCovered(match.range) { continue }
            // 标记符号
            let marker1 = match.range(at: 1)
            if !covered.isFullyCovered(marker1) {
                results.append(HighlightRange(range: marker1, color: colors.bold.withAlphaComponent(0.60), isBold: false, isItalic: false))
                covered.cover(marker1)
            }
            // 标记符号（尾部）
            let marker2 = NSRange(location: match.range.location + match.range.length - marker1.length, length: marker1.length)
            if !covered.isFullyCovered(marker2) {
                results.append(HighlightRange(range: marker2, color: colors.bold.withAlphaComponent(0.60), isBold: false, isItalic: false))
                covered.cover(marker2)
            }
            // 内容
            let contentRange = NSRange(location: marker1.location + marker1.length, length: match.range.length - marker1.length * 2)
            if !covered.isFullyCovered(contentRange) {
                results.append(HighlightRange(range: contentRange, color: colors.bold, isBold: true, isItalic: false))
                covered.cover(contentRange)
            }
        }
    }

    /// 斜体 *text* 或 _text_
    private static func applyItalic(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        // 使用单星号/下划线，但不匹配多星号/下划线的情况
        let pattern = "(?<!\\*)(\\*)(?!\\*)(?=\\S)(.+?)(?<=\\S)(\\*)(?!\\*)"
        // 斜体不应跨行匹配（CommonMark 规范：强调标记不跨越段落边界）
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }
        let matches = regex.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches {
            if covered.isFullyCovered(match.range) { continue }
            // 部分覆盖说明匹配跨越了代码块等边界，应跳过整个匹配
            if covered.isPartiallyCovered(match.range) { continue }
            // 开头标记
            if !covered.isFullyCovered(match.range(at: 1)) {
                results.append(HighlightRange(range: match.range(at: 1), color: colors.italic.withAlphaComponent(0.60), isBold: false, isItalic: false))
                covered.cover(match.range(at: 1))
            }
            // 内容
            if !covered.isFullyCovered(match.range(at: 2)) {
                results.append(HighlightRange(range: match.range(at: 2), color: colors.italic, isBold: false, isItalic: true))
                covered.cover(match.range(at: 2))
            }
            // 结尾标记
            if !covered.isFullyCovered(match.range(at: 3)) {
                results.append(HighlightRange(range: match.range(at: 3), color: colors.italic.withAlphaComponent(0.60), isBold: false, isItalic: false))
                covered.cover(match.range(at: 3))
            }
        }

        // 下划线斜体 _text_ — 与星号斜体一致，分标记/内容着色
        // CommonMark 规则: 开始 _ 左侧不能是字母/数字，结束 _ 右侧不能是字母/数字
        // 这样 tag_name、APP_PATH 等标识符中的下划线不会被误解析为斜体
        let underscorePattern = "(?<![a-zA-Z0-9])_(?=\\S)(.+?)(?<=\\S)_(?![a-zA-Z0-9])"
        // 下划线斜体不应跨行匹配（CommonMark 规范：强调标记不跨越段落边界）
        guard let regex2 = try? NSRegularExpression(pattern: underscorePattern, options: []) else { return }
        let matches2 = regex2.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches2 {
            if covered.isFullyCovered(match.range) { continue }
            // 部分覆盖说明匹配跨越了代码块等边界，应跳过整个匹配
            if covered.isPartiallyCovered(match.range) { continue }
            // 开头 _ 标记（1个字符）
            let openUnderscore = NSRange(location: match.range.location, length: 1)
            if !covered.isFullyCovered(openUnderscore) {
                results.append(HighlightRange(range: openUnderscore, color: colors.italic.withAlphaComponent(0.60), isBold: false, isItalic: false))
                covered.cover(openUnderscore)
            }
            // 内容
            let contentRange = NSRange(location: match.range.location + 1, length: match.range.length - 2)
            if !covered.isFullyCovered(contentRange) {
                results.append(HighlightRange(range: contentRange, color: colors.italic, isBold: false, isItalic: true))
                covered.cover(contentRange)
            }
            // 结尾 _ 标记（1个字符）
            let closeUnderscore = NSRange(location: match.range.location + match.range.length - 1, length: 1)
            if !covered.isFullyCovered(closeUnderscore) {
                results.append(HighlightRange(range: closeUnderscore, color: colors.italic.withAlphaComponent(0.60), isBold: false, isItalic: false))
                covered.cover(closeUnderscore)
            }
        }
    }

    /// 引用块 > text
    private static func applyBlockquotes(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        let pattern = "^(>+)\\s?"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        let matches = regex.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches {
            // > 标记
            let markerRange = match.range(at: 1)
            if !covered.isFullyCovered(markerRange) {
                results.append(HighlightRange(
                    range: markerRange,
                    color: colors.blockquote,
                    isBold: true,
                    isItalic: false
                ))
                covered.cover(markerRange)
            }
        }
    }

    /// 列表标记 - * + 和 1.
    private static func applyListMarkers(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        // 无序列表: - * + 后跟空格
        let unorderedPattern = "^[ \\t]*([-*+])[ \\t]+"
        guard let regex1 = try? NSRegularExpression(pattern: unorderedPattern, options: [.anchorsMatchLines]) else { return }
        let matches1 = regex1.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches1 {
            let markerRange = match.range(at: 1)
            if !covered.isFullyCovered(markerRange) {
                results.append(HighlightRange(
                    range: markerRange,
                    color: colors.listMarker,
                    isBold: true,
                    isItalic: false
                ))
                covered.cover(markerRange)
            }
        }

        // 有序列表: 1. 2) 等
        let orderedPattern = "^[ \\t]*(\\d+[.)])[ \\t]+"
        guard let regex2 = try? NSRegularExpression(pattern: orderedPattern, options: [.anchorsMatchLines]) else { return }
        let matches2 = regex2.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches2 {
            let markerRange = match.range(at: 1)
            if !covered.isFullyCovered(markerRange) {
                results.append(HighlightRange(
                    range: markerRange,
                    color: colors.listMarker,
                    isBold: true,
                    isItalic: false
                ))
                covered.cover(markerRange)
            }
        }

        // 任务列表: - [ ] / - [x]
        let taskPattern = "^[ \\t]*[-*+][ \\t]+(\\[[ xX]\\])[ \\t]"
        guard let regex3 = try? NSRegularExpression(pattern: taskPattern, options: [.anchorsMatchLines]) else { return }
        let matches3 = regex3.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches3 {
            let markerRange = match.range(at: 1)
            if !covered.isFullyCovered(markerRange) {
                results.append(HighlightRange(
                    range: markerRange,
                    color: colors.accent,
                    isBold: false,
                    isItalic: false
                ))
                covered.cover(markerRange)
            }
        }
    }

    /// 水平线 --- *** ___
    private static func applyHorizontalRules(
        _ nsString: NSString, _ fullRange: NSRange, _ colors: SyntaxColors,
        _ results: inout [HighlightRange], _ covered: inout CoveredRanges
    ) {
        let pattern = "^[ \\t]*([-*_])[ \\t]*\\1[ \\t]*\\1([ \\t]*\\1)*[ \\t]*$"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else { return }
        let matches = regex.matches(in: nsString as String, options: [], range: fullRange)

        for match in matches {
            if covered.isFullyCovered(match.range) { continue }
            results.append(HighlightRange(
                range: match.range,
                color: colors.horizontalRule,
                isBold: false,
                isItalic: false
            ))
            covered.cover(match.range)
        }
    }
}

// MARK: - NSTextView 语法高亮应用

extension MarkdownSyntaxHighlighter {

    /// 将高亮结果应用到 NSTextView 的文本存储
    @MainActor
    static func applyHighlights(
        to textView: NSTextView,
        text: String,
        colors: SyntaxColors,
        fontSize: CGFloat
    ) {
        guard let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)

        // 禁用 undo 注册，防止语法高亮的属性变更污染 undo 栈
        // 否则用户按 Cmd+Z 时会尝试撤销高亮属性变更，导致崩溃
        let undoManager = textView.undoManager
        undoManager?.disableUndoRegistration()
        defer { undoManager?.enableUndoRegistration() }

        // 先重置为默认属性
        let defaultFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        let defaultAttrs: [NSAttributedString.Key: Any] = [
            .font: defaultFont,
            .foregroundColor: colors.plain
        ]
        textStorage.beginEditing()
        textStorage.setAttributes(defaultAttrs, range: fullRange)

        // 应用高亮
        let highlights = highlight(text, colors: colors)
        for hl in highlights {
            var attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: hl.color
            ]

            // 背景色（代码块等）
            if let bgColor = hl.backgroundColor {
                attrs[.backgroundColor] = bgColor
            }

            // 合并字体属性
            if hl.isBold && hl.isItalic {
                if let boldItalicFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold).withItalic() {
                    attrs[.font] = boldItalicFont
                }
            } else if hl.isBold {
                attrs[.font] = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
            } else if hl.isItalic {
                if let italicFont = defaultFont.withItalic() {
                    attrs[.font] = italicFont
                }
            }

            textStorage.addAttributes(attrs, range: hl.range)
        }

        textStorage.endEditing()
    }
}

// MARK: - NSFont 斜体辅助

extension NSFont {
    /// 返回该字体的斜体版本，如果系统没有对应的斜体则返回 nil
    func withItalic() -> NSFont? {
        let descriptor = fontDescriptor.withSymbolicTraits([.italic])
        return NSFont(descriptor: descriptor, size: pointSize)
    }
}
