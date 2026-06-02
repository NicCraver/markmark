import SwiftUI

/// 自定义红绿灯按钮（关闭/最小化/最大化），替代系统红绿灯以实现位置控制
struct TrafficLightButtons: View {
    /// 是否显示图标（hover 时显示）
    @State private var isHovering = false

    /// 按钮间距
    private let spacing: CGFloat = 8

    /// 按钮直径
    private let buttonSize: CGFloat = 12

    var body: some View {
        HStack(spacing: spacing) {
            // 关闭按钮
            trafficLightButton(
                color: Color(nsColor: .systemRed),
                icon: "xmark",
                action: closeWindow
            )

            // 最小化按钮
            trafficLightButton(
                color: Color(nsColor: .systemYellow),
                icon: "minus",
                action: miniaturizeWindow
            )

            // 最大化按钮
            trafficLightButton(
                color: Color(nsColor: .systemGreen),
                icon: "plus",
                action: zoomWindow
            )
        }
        .onHover { hovering in
            isHovering = hovering
        }
    }

    // MARK: - 按钮组件

    private func trafficLightButton(
        color: Color,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: buttonSize, height: buttonSize)

                if isHovering {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Color.black.opacity(0.5))
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: buttonSize, height: buttonSize)
    }

    // MARK: - 窗口操作

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }

    private func miniaturizeWindow() {
        NSApp.keyWindow?.miniaturize(nil)
    }

    private func zoomWindow() {
        NSApp.keyWindow?.zoom(nil)
    }
}
