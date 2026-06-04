import AppKit
import SwiftUI

/// 强制 NSScrollView 使用 overlay（细）滚动条样式。
/// 三级搜索策略：supervisor 链 → 兄弟视图 → 祖先区域内搜索。
struct OverlayScrollerHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> OverlayScrollerFinderView {
        OverlayScrollerFinderView()
    }

    func updateNSView(_ nsView: OverlayScrollerFinderView, context: Context) {
        nsView.scheduleReconfigure()
    }
}

final class OverlayScrollerFinderView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            self?.configure()
        }
    }

    func scheduleReconfigure() {
        DispatchQueue.main.async { [weak self] in
            self?.configure()
        }
    }

    private func configure() {
        if let scrollView = searchSuperviewChain() {
            applyThinOverlay(to: scrollView)
            return
        }
        if let scrollView = searchSiblings() {
            applyThinOverlay(to: scrollView)
            return
        }
        if let scrollView = searchAncestorRegion() {
            applyThinOverlay(to: scrollView)
        }
    }

    private func searchSuperviewChain() -> NSScrollView? {
        var candidate: NSView? = superview
        while let parent = candidate {
            if let scrollView = parent as? NSScrollView {
                return scrollView
            }
            candidate = parent.superview
        }
        return nil
    }

    private func searchSiblings() -> NSScrollView? {
        guard let parent = superview else { return nil }
        for sibling in parent.subviews where sibling !== self {
            if let scrollView = findFirstScrollView(in: sibling, depth: 5) {
                return scrollView
            }
        }
        if let grandparent = parent.superview {
            for sibling in grandparent.subviews where sibling !== parent {
                if let scrollView = findFirstScrollView(in: sibling, depth: 5) {
                    return scrollView
                }
            }
        }
        return nil
    }

    /// 从更高的祖先视图中搜索——沿着 supervisor 链向上找最顶层容器，
    /// 然后在该容器内搜索 NSScrollView。
    /// 这避免了搜索整个窗口（影响设置面板），同时能覆盖 Sidebar List 的深层级。
    private func searchAncestorRegion() -> NSScrollView? {
        let ancestor = findTopLevelContainer()
        return findFirstScrollView(in: ancestor, depth: 15)
    }

    /// 找到 helper 视图所在的最高层容器（但不超过窗口 contentView）。
    /// 通过向上遍历 supervisor 链，找到第一个直接作为 contentView 子视图的祖先。
    private func findTopLevelContainer() -> NSView {
        guard let contentView = window?.contentView else { return self }
        var candidate: NSView = self
        while let parent = candidate.superview, parent !== contentView {
            candidate = parent
        }
        return candidate
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

    private func applyThinOverlay(to scrollView: NSScrollView) {
        scrollView.scrollerStyle = .overlay
        if !(scrollView.documentView is NSTextView),
           !(scrollView.verticalScroller is ThinOverlayScroller) {
            scrollView.verticalScroller = ThinOverlayScroller()
        }
    }
}

final class ThinOverlayScroller: NSScroller {
    private static let knobWidth: CGFloat = 6

    override func drawKnob() {
        let knobFrame = rect(for: .knob)
        let thinRect = NSRect(
            x: knobFrame.maxX - Self.knobWidth - 1,
            y: knobFrame.origin.y + 1,
            width: Self.knobWidth,
            height: max(knobFrame.height - 2, Self.knobWidth)
        )
        let path = NSBezierPath(roundedRect: thinRect, xRadius: Self.knobWidth / 2, yRadius: Self.knobWidth / 2)
        let alpha: CGFloat = isHighlighted ? 0.5 : 0.3
        NSColor.labelColor.withAlphaComponent(alpha).setFill()
        path.fill()
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}
}
