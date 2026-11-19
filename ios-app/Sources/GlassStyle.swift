import SwiftUI

// MARK: - Liquid Glass 材质
//
// iOS 26+：系统原生 Liquid Glass（glassEffect / .regular），真实折射与景深；
// iOS 16–25：ultraThinMaterial + 高光描边模拟。
//
// 注：此前"玻璃错位出屏"的真正根因是画布被撑大（背景子视图溢出 +
// 窗口画布大于物理屏幕），已于 v12 修复：背景改为零布局影响的
// .background，根视图钳制到物理屏幕尺寸。画布正确后 glassEffect
// 在元素自身 bounds 上渲染，恢复安全使用。
//
// 结构原则（保留）：
// 1. 绝不用 GlassEffectContainer 包全屏（离屏合成有错位风险）。
// 2. 玻璃只画在元素自身 bounds 上。
// 3. 可点击元素统一走 GlassButtonStyle（ButtonStyle 内画玻璃 + 按压反馈）。

// MARK: - 静态玻璃（非按钮元素：输入面板、气泡、分隔条、胶囊）

extension View {
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        } else {
            self.background { simulatedGlass(cornerRadius: cornerRadius) }
        }
    }
}

// MARK: - 按钮玻璃（可点击元素：返回/视频/加号/通话控制等）

struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat

    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            configuration.label
                .background { simulatedGlass(cornerRadius: cornerRadius) }
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
        }
    }
}

extension View {
    /// 便捷入口：把按钮换成玻璃样式
    func glassButton(cornerRadius: CGFloat) -> some View {
        buttonStyle(GlassButtonStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - 旧系统模拟玻璃（iOS 16–25 回退）

/// 顶层函数：供 glassPanel 与 GlassButtonStyle 共用（无需 View 接收者）
func simulatedGlass(cornerRadius: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    return shape
        .fill(.ultraThinMaterial)
        .overlay(
            LinearGradient(
                colors: [Color.white.opacity(0.30), Color.white.opacity(0.05), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .blendMode(.plusLighter)
            .clipShape(shape)
        )
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.55), Color.white.opacity(0.12)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.8
            )
        )
        .shadow(color: Color.black.opacity(0.18), radius: 16, x: 0, y: 10)
}

// MARK: - 发送气泡渐变色

enum Palette {
    static let sendTop = Color(red: 0.36, green: 0.70, blue: 1.0)
    static let sendMid = Color(red: 0.12, green: 0.47, blue: 1.0)
    static let sendBottom = Color(red: 0.02, green: 0.36, blue: 0.92)
}
