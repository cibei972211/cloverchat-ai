import SwiftUI

// MARK: - Liquid Glass 材质
//
// iOS 26+ 走系统原生 Liquid Glass（glassEffect），呈现真实的折射与景深；
// iOS 16–25 回退到 ultraThinMaterial + 高光描边的模拟玻璃。
//
// 重要教训：不要用 GlassEffectContainer 包裹整个屏幕。实测其离屏合成会把玻璃形状
// 错位渲染到屏幕外（按钮玻璃卡一半出屏，白色图标位置却是对的）。每个元素独立
// glassEffect 即可，玻璃画在自身 bounds 上，位置天然正确。

extension View {
    /// cornerRadius: 玻璃形状圆角
    /// interactive:  是否启用 iOS 26 原生按压反馈（放大 + 流光 + 触点高光）。
    ///              仅对可点击元素（Button）生效，是真·Liquid Glass 的标志动画。
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            if interactive {
                self.glassEffect(
                    .regular.interactive(),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            } else {
                self.glassEffect(
                    .regular,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
            }
        } else {
            self.background {
                let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                shape
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
        }
    }
}

enum Palette {
    static let sendTop = Color(red: 0.36, green: 0.70, blue: 1.0)
    static let sendMid = Color(red: 0.12, green: 0.47, blue: 1.0)
    static let sendBottom = Color(red: 0.02, green: 0.36, blue: 0.92)
}
