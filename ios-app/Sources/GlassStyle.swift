import SwiftUI

// MARK: - Liquid-look Glass（材质模拟）
//
// v13–v15 实机结论：本机型环境下，glassEffect（无论 .interactive 还是
// 普通 .regular）覆盖到的按钮全部收不到触摸——玻璃在内层、外层、有无
// 按压样式都试过；而同一块玻璃里的 TextField 却能正常输入。
// 原生液态玻璃与"按钮可点"不可兼得，本构建彻底移除 glassEffect，
// 改用材质高仿：真实模糊打底 + 流光 + 厚度描边，视觉向液态玻璃看齐。
// v12（纯材质方案）已实测：按钮、滚动、按压反馈全部正常。

// MARK: - 玻璃外观

/// 顶层函数：静态面板与按钮样式共用
func simulatedGlass(cornerRadius: CGFloat) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    return shape
        .fill(.ultraThinMaterial)
        // 左上斜向流光
        .overlay(
            LinearGradient(
                colors: [Color.white.opacity(0.34), Color.white.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .blendMode(.plusLighter)
            .clipShape(shape)
        )
        // 底缘环境反光（玻璃厚度感）
        .overlay(
            LinearGradient(
                colors: [Color.clear, Color.white.opacity(0.10)],
                startPoint: .center,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)
            .clipShape(shape)
        )
        // 高光描边：上亮中弱下回亮（液态玻璃的厚度感）
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.65), location: 0),
                        .init(color: Color.white.opacity(0.20), location: 0.55),
                        .init(color: Color.white.opacity(0.42), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
        .shadow(color: Color.black.opacity(0.20), radius: 14, x: 0, y: 8)
}

extension View {
    /// 静态玻璃（非交互元素：输入面板、气泡、分隔条、胶囊）
    func glassPanel(cornerRadius: CGFloat) -> some View {
        background { simulatedGlass(cornerRadius: cornerRadius) }
    }
}

// MARK: - 按钮玻璃（可点击元素：返回/视频/加号/通话控制等）

/// 模拟玻璃背景 + 按压缩放/变暗反馈
struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background { simulatedGlass(cornerRadius: cornerRadius) }
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .opacity(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    /// 便捷入口：把按钮换成玻璃样式
    func glassButton(cornerRadius: CGFloat) -> some View {
        buttonStyle(GlassButtonStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - 配色

enum Palette {
    static let sendTop = Color(red: 0.36, green: 0.70, blue: 1.0)
    static let sendMid = Color(red: 0.12, green: 0.47, blue: 1.0)
    static let sendBottom = Color(red: 0.02, green: 0.36, blue: 0.92)
}
