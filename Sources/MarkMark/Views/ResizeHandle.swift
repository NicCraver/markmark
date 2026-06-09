import SwiftUI
import MarkdownReaderKit

/// Sidebar 边缘拖拽分隔线
/// 使用 NSViewRepresentable 直接处理鼠标事件，避免 SwiftUI DragGesture 在 macOS 上不可靠的问题
struct ResizeHandle: View {
    let appViewModel: AppViewModel

    var body: some View {
        ResizeHandleView(appViewModel: appViewModel)
            .frame(width: 8)
    }
}

// MARK: - NSViewRepresentable 拖拽处理

/// 使用 AppKit NSView 直接处理鼠标事件，确保拖拽可靠工作
private struct ResizeHandleView: NSViewRepresentable {
    let appViewModel: AppViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(appViewModel: appViewModel)
    }

    func makeNSView(context: Context) -> ResizeHandleNSView {
        let view = ResizeHandleNSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ nsView: ResizeHandleNSView, context: Context) {
        context.coordinator.appViewModel = appViewModel
    }
}

// MARK: - Coordinator

extension ResizeHandleView {
    final class Coordinator {
        var appViewModel: AppViewModel

        init(appViewModel: AppViewModel) {
            self.appViewModel = appViewModel
        }
    }
}

// MARK: - AppKit 拖拽视图

/// 直接处理鼠标事件的 NSView
/// 通过 NSTrackingArea + cursorUpdate + mouseMoved 管理光标，
/// mouseDown/mouseDragged/mouseUp 实现拖拽
///
/// 光标管理策略（经 Apple Developer Forums 验证的最可靠方案）：
/// - 使用 NSTrackingArea 追踪鼠标进出和移动
/// - 使用 NSCursor.set()（而非 push/pop）直接设置光标，避免栈失衡干扰窗口边缘光标
/// - 空的 cursorUpdate(with:) 阻止系统重置光标
/// - mouseMoved 持续重设光标，对抗 SwiftUI 的光标重置
private final class ResizeHandleNSView: NSView {
    weak var coordinator: ResizeHandleView.Coordinator?

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

    // 阻止系统重置光标（关键：空实现防止 SwiftUI/AppKit 覆盖自定义光标）
    override func cursorUpdate(with event: NSEvent) {}

    override func mouseEntered(with event: NSEvent) {
        isMouseInBounds = true
        NSCursor.resizeLeftRight.set()
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInBounds = false
        // 不直接设为 arrow，而是让窗口的 cursor rect 系统接管，
        // 这样鼠标移到窗口边缘时系统能正确显示对应的缩放光标
        window?.invalidateCursorRects(for: self)
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            NSCursor.resizeLeftRight.set()
        }
        // 鼠标不在 resize handle 内时不主动设光标，让系统自行管理
    }

    // MARK: - 拖拽处理

    override func mouseDown(with event: NSEvent) {
        isDragging = true
        lastMouseX = event.locationInWindow.x
        // 拖拽期间保持光标
        NSCursor.resizeLeftRight.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard isDragging, let coordinator else { return }

        // 拖拽期间持续保持光标
        NSCursor.resizeLeftRight.set()

        let currentX = event.locationInWindow.x
        let deltaX = currentX - lastMouseX
        lastMouseX = currentX

        let newWidth = coordinator.appViewModel.sidebarWidth + deltaX
        let clampedWidth = max(
            AppViewModel.minSidebarWidth,
            min(AppViewModel.maxSidebarWidth, newWidth)
        )
        coordinator.appViewModel.updateSidebarWidth(clampedWidth)
    }

    override func mouseUp(with event: NSEvent) {
        guard isDragging, let coordinator else { return }
        isDragging = false
        coordinator.appViewModel.handleDragEnded()
        // 拖拽结束后恢复光标
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            NSCursor.resizeLeftRight.set()
        } else {
            // 不强制设为 arrow，让系统光标 rect 接管
            window?.invalidateCursorRects(for: self)
        }
    }
}
