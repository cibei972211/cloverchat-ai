import SwiftUI

// MARK: - Liquid Glass 材质
//
// iOS 26+：系统原生 Liquid Glass（glassEffect / .regular），真实折射与景深；
// iOS 16–25：ultraThinMaterial + 高光描边模拟。
//
// 结构原则：
// 1. 绝不用 GlassEffectContainer 包全屏（离屏合成有错位风险）。
// 2. 玻璃只画在元素自身 bounds 上。
// 3. 可点击元素绝不用 .interactive() 玻璃——v13/v14 实机验证：
//    interactive 的按压手势会拦截 Button 的点击（玻璃放 label 内层
//    或外层都一样），导致按钮点不动。非交互 .regular 玻璃不拦触摸
//    （输入面板里的 TextField 一直可正常输入），按钮按压反馈改由
//    isPressed 缩放提供。

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

/// 按压反馈：缩放 + 轻微变暗（玻璃在外层，样式只动 label）
struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// 旧系统回退（iOS 16–25）：模拟玻璃背景 + 按压缩放
struct GlassFallbackButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background { simulatedGlass(cornerRadius: cornerRadius) }
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    /// 便捷入口：把按钮换成玻璃样式
    @ViewBuilder
    func glassButton(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
                .buttonStyle(GlassButtonStyle())
                .glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            self.buttonStyle(GlassFallbackButtonStyle(cornerRadius: cornerRadius))
        }
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
