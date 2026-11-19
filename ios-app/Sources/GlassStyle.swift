import SwiftUI

// MARK: - 玻璃材质（全平台统一模拟实现）
//
// 结论（多轮真机验证）：iOS 26 原生 glassEffect 在本项目的按钮/面板上
// 会把玻璃形状错位渲染到布局框之外（布局本身正确——非玻璃元素位置全部正确，
// 只有玻璃形状跑偏）。因此所有系统版本统一改用 ultraThinMaterial +
// 高光描边模拟玻璃：它就是普通的背景绘制，严格画在元素自身 bounds 上，
// 位置由 SwiftUI 布局保证。
//
// 结构原则：
// 1. 绝不使用 GlassEffectContainer。
// 2. 玻璃只画在元素自身 bounds 上。
// 3. 可点击元素统一走 GlassButtonStyle（玻璃 + 按压反馈）。

// MARK: - 静态玻璃（非按钮元素：输入面板、气泡、分隔条、胶囊）

extension View {
    func glassPanel(cornerRadius: CGFloat) -> some View {
        background { simulatedGlass(cornerRadius: cornerRadius) }
    }
}

// MARK: - 按钮玻璃（可点击元素：返回/视频/加号/通话控制等）

struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background { simulatedGlass(cornerRadius: cornerRadius) }
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    /// 便捷入口：把按钮换成玻璃样式
    func glassButton(cornerRadius: CGFloat) -> some View {
        buttonStyle(GlassButtonStyle(cornerRadius: cornerRadius))
    }
}

// MARK: - 模拟玻璃

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
