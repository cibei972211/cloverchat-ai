import SwiftUI

// MARK: - Liquid Glass 材质
//
// iOS 26+ 走系统原生 Liquid Glass（glassEffect），呈现真实的折射、景深与融合效果；
// iOS 16–25 回退到 ultraThinMaterial + 高光描边的模拟玻璃。

extension View {
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
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

// 包裹一层 GlassEffectContainer（iOS 26+），让多个液态玻璃形状相互融合、可变形，
// 这是系统原生 Liquid Glass 看起来“融在一起”的关键。
extension View {
    @ViewBuilder
    func glassContainer() -> some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer { self }
        } else {
            self
        }
    }
}

enum Palette {
    static let sendTop = Color(red: 0.36, green: 0.70, blue: 1.0)
    static let sendMid = Color(red: 0.12, green: 0.47, blue: 1.0)
    static let sendBottom = Color(red: 0.02, green: 0.36, blue: 0.92)
}
