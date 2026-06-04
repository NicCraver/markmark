import AppKit
import SwiftUI

/// 强制最近的 NSScrollView 使用 overlay（细）滚动条样式。
/// 放在 ScrollView 内部或 List 的 .background() 中均可自动查找。
struct OverlayScrollerHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> OverlayScrollerFinderView {
        OverlayScrollerFinderView()
    }

    func updateNSView(_ nsView: OverlayScrollerFinderView, context: Context) {}
}

final class OverlayScrollerFinderView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        forceOverlayScroller()
    }

    private func forceOverlayScroller() {
        var candidate: NSView? = superview
        while let parent = candidate {
            if let scrollView = parent as? NSScrollView {
                scrollView.scrollerStyle = .overlay
                return
            }
            for sibling in parent.subviews {
                if let scrollView = findFirstScrollView(in: sibling, depth: 3) {
                    scrollView.scrollerStyle = .overlay
                    return
                }
            }
            candidate = parent.superview
        }
    }

    private func findFirstScrollView(in view: NSView, depth: Int) -> NSScrollView? {
        if let scrollView = view as? NSScrollView {
            return scrollView
        }
        guard depth > 0 else { return nil }
        for subview in view.subviews {
            if let found = findFirstScrollView(in: subview, depth: depth - 1) {
                return found
            }
        }
        return nil
    }
}
