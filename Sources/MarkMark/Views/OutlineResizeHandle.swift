import SwiftUI
import MarkdownReaderKit

/// 大纲侧边栏边缘拖拽分隔线
/// 与 ResizeHandle 类似，但拖拽方向相反（向左拖 = 宽度增大）
struct OutlineResizeHandle: View {
    let appViewModel: AppViewModel
    @Environment(\.themeColors) private var themeColors

    var body: some View {
        OutlineResizeHandleView(appViewModel: appViewModel)
            .frame(width: 8)
            .overlay(
                // 1px 分隔线，视觉上替代原来的 Rectangle 分隔线
                Rectangle()
                    .fill(themeColors.border)
                    .frame(width: 1)
                    .padding(.trailing, 3),
                alignment: .trailing
            )
    }
}

// MARK: - NSViewRepresentable 拖拽处理

private struct OutlineResizeHandleView: NSViewRepresentable {
    let appViewModel: AppViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(appViewModel: appViewModel)
    }

    func makeNSView(context: Context) -> OutlineResizeHandleNSView {
        let view = OutlineResizeHandleNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: OutlineResizeHandleNSView, context: Context) {
        context.coordinator.appViewModel = appViewModel
    }
}

// MARK: - Coordinator

extension OutlineResizeHandleView {
    final class Coordinator {
        var appViewModel: AppViewModel

        init(appViewModel: AppViewModel) {
            self.appViewModel = appViewModel
        }
    }
}

// MARK: - AppKit 拖拽视图

/// 大纲侧边栏的拖拽 NSView
/// 拖拽方向：向左拖动增大宽度（与左侧 Sidebar 方向相反）
private final class OutlineResizeHandleNSView: NSView {
    weak var coordinator: OutlineResizeHandleView.Coordinator?

    private var isDragging = false
    private var lastMouseX: CGFloat = 0
    private var isMouseInBounds = false

    // MARK: - Tracking Area（光标管理）

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .mouseMoved,
            .activeAlways,
            .inVisibleRect,
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingAreas()
    }

    override func cursorUpdate(with event: NSEvent) {}

    override func mouseEntered(with event: NSEvent) {
        isMouseInBounds = true
        NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInBounds = false
        window?.invalidateCursorRects(for: self)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            NSCursor.resizeLeftRight.set()
        }
    }

    // MARK: - 拖拽处理

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        lastMouseX = event.locationInWindow.x
        NSCursor.resizeLeftRight.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let coordinator else { return }

        NSCursor.resizeLeftRight.set()

        let currentX = event.locationInWindow.x
        // 向左拖动 = deltaX 为负 = 宽度增大（与左侧 Sidebar 方向相反）
        let deltaX = lastMouseX - currentX
        lastMouseX = currentX

        let newWidth = coordinator.appViewModel.outlineWidth + deltaX
        let clampedWidth = max(
            AppViewModel.minOutlineWidth,
            min(AppViewModel.maxOutlineWidth, newWidth)
        )
        coordinator.appViewModel.updateOutlineWidth(clampedWidth)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging, let coordinator else { return }
        isDragging = false
        coordinator.appViewModel.handleOutlineDragEnded()
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            NSCursor.resizeLeftRight.set()
        } else {
            window?.invalidateCursorRects(for: self)
        }
    }
}
