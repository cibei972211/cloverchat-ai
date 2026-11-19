import SwiftUI

// MARK: - Liquid Glass 材质
//
// iOS 26+：系统原生 Liquid Glass（glassEffect / .regular），真实折射与景深；
// iOS 16–25：ultraThinMaterial + 高光描边模拟。
//
// 结构原则：
// 1. 绝不用 GlassEffectContainer 包全屏（离屏合成有错位风险）。
// 2. 玻璃只画在元素自身 bounds 上。
// 3. 可点击元素：iOS 26 玻璃必须套在 Button 外层（.glassButton 修饰符
//    里先 .buttonStyle(.plain) 再 .glassEffect(.interactive())）——
//    若把 interactive 玻璃放进 ButtonStyle 的 label 内部，玻璃层会
//    拦截触摸导致按钮点不动；外层包裹则是 Apple 文档标准用法，
//    按压反馈与点击动作都正常。

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

extension View {
    /// 便捷入口：把按钮换成玻璃样式
    @ViewBuilder
    func glassButton(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(.plain)
                .glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            self.buttonStyle(GlassButtonStyle(cornerRadius: cornerRadius))
        }
    }
}

/// 旧系统回退（iOS 16–25）：模拟玻璃 + isPressed 缩放
struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background { simulatedGlass(cornerRadius: cornerRadius) }
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
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

// MARK: - 配色

enum Palette {
    static let sendTop = Color(red: 0.36, green: 0.70, blue: 1.0)
    static let sendMid = Color(red: 0.12, green: 0.47, blue: 1.0)
    static let sendBottom = Color(red: 0.02, green: 0.36, blue: 0.92)
    /// 发出气泡的玻璃 tint（半透蓝）
    static let sendTint = Color(red: 0.08, green: 0.42, blue: 0.95)
}
