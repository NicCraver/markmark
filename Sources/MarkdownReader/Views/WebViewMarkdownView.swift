import SwiftUI
import WebKit

class MarkdownNavigationDecider: WebPage.NavigationDeciding {
    func decidePolicy(
        for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences
    ) async -> WKNavigationActionPolicy {
        guard let url = action.request.url else { return .allow }

        if url.scheme == "mr" || url.scheme == "about" {
            return .allow
        }

        if url.scheme == "file" {
            if action.target?.isMainFrame == true && action.navigationType == .linkActivated {
                return .cancel
            }
            return .allow
        }

        NSWorkspace.shared.open(url)
        return .cancel
    }

    func decidePolicy(for response: WebPage.NavigationResponse) async -> WKNavigationResponsePolicy {
        .allow
    }

    func decideAuthenticationChallengeDisposition(for challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        (.performDefaultHandling, nil)
    }
}

struct WebViewMarkdownView: View {
    let content: String
    let fileURL: URL?
    var contentPadding: CGFloat = 20
    var scrollToLine: Int?
    let themeCSS: String
    var isDark: Bool = true
    var onVisibleHeadingChanged: ((MarkdownHTMLService.HeadingInfo?) -> Void)?

    @State private var page = WebPage()
    @State private var scrollPosition = ScrollPosition(edge: .top)
    @State private var lastLoadedContent: String = ""
    @State private var lastLoadedURL: URL?
    @State private var scrollSyncTimer: Timer?
    @State private var isConfigured = false
    @State private var currentHeadings: [MarkdownHTMLService.HeadingInfo] = []

    var body: some View {
        WebView(page)
            .webViewScrollPosition($scrollPosition)
            .webViewLinkPreviews(.disabled)
            .webViewTextSelection(.enabled)
            .webViewBackForwardNavigationGestures(.disabled)
            .webViewMagnificationGestures(.enabled)
            .webViewContentBackground(.hidden)
            .webViewOnScrollGeometryChange(for: Int.self, of: { geometry in
                Int(geometry.contentOffset.y)
            }, action: { _, _ in
                scheduleScrollSync()
            })
            .onAppear {
                configureAndLoad()
            }
            .onChange(of: content) { _, _ in
                if content == lastLoadedContent { return }
                if lastLoadedContent.isEmpty {
                    loadContent()
                } else {
                    updateContent(content)
                    lastLoadedContent = content
                }
            }
            .onChange(of: fileURL) { _, _ in
                loadContent()
            }
            .onChange(of: scrollToLine) { _, newValue in
                if let line = newValue {
                    scrollToLineNumber(line)
                }
            }
            .onChange(of: themeCSS) { _, _ in
                updateThemeCSS(themeCSS)
            }
            .onChange(of: contentPadding) { _, newValue in
                updateContentPadding(newValue)
            }
            .onDisappear {
                scrollSyncTimer?.invalidate()
            }
            .environment(\.openURL, OpenURLAction { url in
                NSWorkspace.shared.open(url)
                return .handled
            })
    }

    private func configureAndLoad() {
        guard !isConfigured else {
            loadContent()
            return
        }
        isConfigured = true

        let scheme = URLScheme("mr")!
        let handler = MarkdownURLSchemeHandler(baseURL: fileURL?.deletingLastPathComponent())
        var configuration = WebPage.Configuration()
        configuration.urlSchemeHandlers[scheme] = handler

        let navigationDecider = MarkdownNavigationDecider()
        page = WebPage(
            configuration: configuration,
            navigationDecider: navigationDecider
        )

        loadContent()
    }

    private func loadContent() {
        let baseURL = fileURL?.deletingLastPathComponent()
        let html = MarkdownHTMLService.buildFullHTML(
            content: content,
            themeCSS: themeCSS,
            contentPadding: contentPadding,
            baseURL: baseURL,
            isDark: isDark
        )

        let renderResult = MarkdownHTMLService.render(content, baseURL: baseURL)
        currentHeadings = renderResult.headings

        let effectiveBaseURL = baseURL ?? URL(string: "about:blank")!
        _ = page.load(html: html, baseURL: effectiveBaseURL)
        lastLoadedContent = content
        lastLoadedURL = fileURL
    }

    private func updateContent(_ content: String) {
        let baseURL = fileURL?.deletingLastPathComponent()
        let renderResult = MarkdownHTMLService.render(content, baseURL: baseURL)
        currentHeadings = renderResult.headings

        let escapedHTML = renderResult.html
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "'", with: "\\'")

        Task { @MainActor [escapedHTML] in
            _ = try? await page.callJavaScript("MR.replaceContent('\(escapedHTML)')")
        }
    }

    private func scrollToLineNumber(_ lineNumber: Int) {
        Task { @MainActor [lineNumber] in
            _ = try? await page.callJavaScript("MR.scrollToLine(\(lineNumber))")
        }
    }

    private func updateThemeCSS(_ themeCSS: String) {
        let escaped = themeCSS
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "'", with: "\\'")

        Task { @MainActor [escaped] in
            do {
                _ = try await page.callJavaScript("document.getElementById('mr-theme-style').textContent = '\(escaped)'")
                _ = try await page.callJavaScript("MR.rerenderMermaid()")
            } catch {
                print("[MarkdownReader] updateThemeCSS failed: \(error)")
            }
        }
    }

    private func updateContentPadding(_ padding: CGFloat) {
        Task { @MainActor [padding] in
            _ = try? await page.callJavaScript("document.documentElement.style.setProperty('--content-padding', '\(padding)px')")
        }
    }

    private func scheduleScrollSync() {
        scrollSyncTimer?.invalidate()
        scrollSyncTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
            Task { @MainActor in
                guard let result = try? await page.callJavaScript("MR.getVisibleHeading()") else {
                    return
                }
                let dict = result as? [String: Any]
                guard let id = dict?["id"] as? String,
                      let level = dict?["level"] as? Int,
                      let title = dict?["title"] as? String,
                      let lineNumber = dict?["lineNumber"] as? Int else {
                    onVisibleHeadingChanged?(nil)
                    return
                }
                onVisibleHeadingChanged?(MarkdownHTMLService.HeadingInfo(id: id, level: level, title: title, lineNumber: lineNumber))
            }
        }
    }
}
