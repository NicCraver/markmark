import Testing
@testable import MarkdownReaderKit

// MARK: - locateRange

@Suite("CriticMarkup.locateRange")
struct CriticMarkupLocateTests {

    @Test("finds a unique substring")
    func uniqueMatch() {
        let source = "The quick brown fox"
        let range = CriticMarkup.locateRange(in: source, selectedText: "brown", nearLine: 1)
        #expect(range != nil)
        #expect(source[range!] == "brown")
    }

    @Test("returns nil when text is absent")
    func absent() {
        #expect(CriticMarkup.locateRange(in: "hello world", selectedText: "zzz", nearLine: 1) == nil)
    }

    @Test("returns nil for empty selection")
    func emptySelection() {
        #expect(CriticMarkup.locateRange(in: "hello", selectedText: "", nearLine: 1) == nil)
    }

    @Test("picks the occurrence nearest to the hint line")
    func nearestLine() {
        // "cat" appears on line 1 and line 4 — nearLine 4 should pick the second.
        let source = "cat one\ntwo\nthree\ncat four"
        let range = CriticMarkup.locateRange(in: source, selectedText: "cat", nearLine: 4)
        #expect(range != nil)
        // The chosen "cat" should be on line 4 (offset after the three newlines)
        let lineOfMatch = source[source.startIndex..<range!.lowerBound].filter { $0 == "\n" }.count + 1
        #expect(lineOfMatch == 4)
    }

    @Test("near line 1 picks the first occurrence")
    func nearestLineFirst() {
        let source = "cat one\ntwo\nthree\ncat four"
        let range = CriticMarkup.locateRange(in: source, selectedText: "cat", nearLine: 1)
        let lineOfMatch = source[source.startIndex..<range!.lowerBound].filter { $0 == "\n" }.count + 1
        #expect(lineOfMatch == 1)
    }
}

// MARK: - apply

@Suite("CriticMarkup.apply")
struct CriticMarkupApplyTests {

    @Test("delete wraps selection in {-- --}")
    func delete() {
        let out = CriticMarkup.apply(.delete, to: "keep this gone", selectedText: "this", nearLine: 1)
        #expect(out == "keep {--this--} gone")
    }

    @Test("highlight wraps selection in {== ==}")
    func highlight() {
        let out = CriticMarkup.apply(.highlight, to: "look here now", selectedText: "here", nearLine: 1)
        #expect(out == "look {==here==} now")
    }

    @Test("comment highlights selection and appends {>> <<}")
    func comment() {
        let out = CriticMarkup.apply(.comment("why?"), to: "fix this part", selectedText: "this", nearLine: 1)
        #expect(out == "fix {==this==}{>>why?<<} part")
    }

    @Test("replace produces a {~~old~>new~~} substitution")
    func replace() {
        let out = CriticMarkup.apply(.replace("that"), to: "use this here", selectedText: "this", nearLine: 1)
        #expect(out == "use {~~this~>that~~} here")
    }

    @Test("insert appends an addition after the selection")
    func insert() {
        let out = CriticMarkup.apply(.insert(" extra"), to: "add here", selectedText: "here", nearLine: 1)
        #expect(out == "add here{++ extra++}")
    }

    @Test("apply returns nil when selection not found")
    func notFound() {
        #expect(CriticMarkup.apply(.delete, to: "abc", selectedText: "xyz", nearLine: 1) == nil)
    }

    @Test("apply targets the occurrence nearest the hint line")
    func nearestLine() {
        let source = "drop me\n\n\ndrop me"
        let out = CriticMarkup.apply(.delete, to: source, selectedText: "drop me", nearLine: 4)
        #expect(out == "drop me\n\n\n{--drop me--}")
    }
}

// MARK: - edit / delete comment

@Suite("CriticMarkup comment editing")
struct CriticMarkupCommentTests {

    @Test("editComment rewrites the comment text in place")
    func edit() {
        let src = "看这里{==重点==}{>>原评论<<}结束"
        let out = CriticMarkup.editComment(in: src, oldComment: "原评论", newComment: "新评论", nearLine: 1)
        #expect(out == "看这里{==重点==}{>>新评论<<}结束")
    }

    @Test("editComment returns nil when the comment is absent")
    func editMissing() {
        #expect(CriticMarkup.editComment(in: "no comment here", oldComment: "x", newComment: "y", nearLine: 1) == nil)
    }

    @Test("deleteComment of a comment-only mark removes just the comment")
    func deleteCommentOnly() {
        let src = "结论存疑{>>来源？<<}。"
        let out = CriticMarkup.deleteComment(in: src, comment: "来源？", nearLine: 1)
        #expect(out == "结论存疑。")
    }

    @Test("deleteComment unwraps the paired highlight too")
    func deleteUnwrapsHighlight() {
        // 评论是用 {==sel==}{>>c<<} 创建的，删除评论应连同高亮一起还原为原文
        let src = "请改{==这一段==}{>>太啰嗦<<}内容"
        let out = CriticMarkup.deleteComment(in: src, comment: "太啰嗦", nearLine: 1)
        #expect(out == "请改这一段内容")
    }

    @Test("deleteComment targets the occurrence nearest the hint line")
    func deleteNearest() {
        let src = "a{>>dup<<}\n\n\nb{>>dup<<}"
        let out = CriticMarkup.deleteComment(in: src, comment: "dup", nearLine: 4)
        #expect(out == "a{>>dup<<}\n\n\nb")
    }
}

// MARK: - accept / reject / strip

@Suite("CriticMarkup transforms")
struct CriticMarkupTransformTests {

    let sample = "a{++b++}c{--d--}e{~~f~>g~~}h{==i==}j{>>k<<}l"

    @Test("accepting applies all suggested changes")
    func accepting() {
        // additions kept, deletions removed, substitution→new, highlight kept (content), comment removed
        #expect(CriticMarkup.accepting(sample) == "abceghijl")
    }

    @Test("rejecting reverts to the original text")
    func rejecting() {
        // additions removed, deletions kept, substitution→old, highlight kept (content), comment removed
        #expect(CriticMarkup.rejecting(sample) == "acdefhijl")
    }

    @Test("hasMarkup detects presence")
    func hasMarkup() {
        #expect(CriticMarkup.hasMarkup(sample))
        #expect(!CriticMarkup.hasMarkup("plain text only"))
    }
}

// MARK: - export for AI

@Suite("CriticMarkup.exportForAI")
struct CriticMarkupExportTests {

    @Test("includes the marked source verbatim")
    func includesSource() {
        let marked = "Hello {--world--}"
        let out = CriticMarkup.exportForAI(marked)
        #expect(out.contains(marked))
    }

    @Test("includes a guiding prompt that explains CriticMarkup")
    func includesPrompt() {
        let out = CriticMarkup.exportForAI("x")
        #expect(out.contains("CriticMarkup"))
        // mentions the core syntaxes so the AI understands the marks
        #expect(out.contains("{--"))
        #expect(out.contains("{++"))
        #expect(out.contains("{>>"))
    }

    @Test("a custom prompt overrides the default header")
    func customPrompt() {
        let out = CriticMarkup.exportForAI("body", prompt: "MY HEADER")
        #expect(out.contains("MY HEADER"))
        #expect(out.contains("body"))
    }
}

// MARK: - HTML rendering

@Suite("CriticMarkup.renderToHTML")
struct CriticMarkupHTMLTests {

    @Test("addition becomes an <ins> with a critic class")
    func addition() {
        let html = CriticMarkup.renderToHTML("a {++new++} b")
        #expect(html.contains("<ins"))
        #expect(html.contains("critic"))
        #expect(html.contains("new"))
        #expect(!html.contains("{++"))
    }

    @Test("deletion becomes a <del>")
    func deletion() {
        let html = CriticMarkup.renderToHTML("a {--old--} b")
        #expect(html.contains("<del"))
        #expect(!html.contains("--}"))
    }

    @Test("substitution becomes a <del> followed by an <ins>")
    func substitution() {
        let html = CriticMarkup.renderToHTML("{~~old~>new~~}")
        #expect(html.contains("<del"))
        #expect(html.contains("<ins"))
        let delIdx = html.range(of: "<del")!.lowerBound
        let insIdx = html.range(of: "<ins")!.lowerBound
        #expect(delIdx < insIdx)
    }

    @Test("highlight becomes a <mark>")
    func highlight() {
        let html = CriticMarkup.renderToHTML("{==important==}")
        #expect(html.contains("<mark"))
        #expect(html.contains("important"))
    }

    @Test("comment becomes a titled span carrying the comment text")
    func comment() {
        let html = CriticMarkup.renderToHTML("{>>look here<<}")
        #expect(html.contains("critic-comment"))
        #expect(html.contains("look here"))
        #expect(!html.contains("<<}"))
    }

    @Test("comment text is attribute-escaped")
    func commentEscaped() {
        let html = CriticMarkup.renderToHTML("{>>a \"quote\" & <tag><<}")
        #expect(!html.contains("\"quote\""))   // quotes escaped inside the title attribute
        #expect(html.contains("&amp;") || html.contains("&quot;"))
    }
}

// MARK: - integration with the markdown→HTML pipeline

@Suite("MarkdownHTMLService CriticMarkup integration")
struct CriticMarkupPipelineTests {

    @Test("a deletion in a paragraph renders as a critic <del>")
    func deletionInParagraph() {
        let result = MarkdownHTMLService.render("This is {--wrong--} text.")
        #expect(result.html.contains("critic"))
        #expect(result.html.contains("<del"))
    }

    @Test("critic markup inside fenced code is left untouched")
    func codeUntouched() {
        let md = "```\nkeep {--literal--} here\n```"
        let result = MarkdownHTMLService.render(md)
        // Inside code, the literal braces must survive (escaped), not become <del>
        #expect(result.html.contains("{--literal--}"))
    }
}
