import SwiftUI
import UIKit

// MARK: - 液态玻璃外观（材质模拟，v16）
//
// 前情（v13–v15 实机结论）：本机型环境下，glassEffect（.interactive / .regular
// 都一样）覆盖到的按钮全部收不到触摸——玻璃在内层、外层、有无按压样式都试过；
// 同一块玻璃里的 TextField 却能正常输入。原生液态玻璃与"按钮可点"不可兼得，
// 所以本构建继续走"材质高仿"路线：
//   真实模糊打底 + 着色层 + 左上流光 + 按压时高光位移 + 厚度描边 + 底缘环境光。
// v16 相对 v12 的变化：着色层（蓝/红玻璃）、按压高光位移、统一触感反馈。

// MARK: - 触感反馈

/// 反馈类型：按钮按下 / 轻触 / 选择 / 成功 / 警告
enum HapticKind {
    case tap        // 普通按钮按下
    case soft       // 轻触发：发送、切换
    case pick       // 选择类：主题、列表
    case success    // 确认成功
    case warning    // 危险操作、失败
}

/// 统一触感入口。
/// 用 UIFeedbackGenerator（iOS 16 兼容，不依赖 iOS 17 的 .sensoryFeedback）。
/// 每次触发后立刻 prepare()，连续点击也不会掉手感。
enum Haptics {
    private static let light = UIImpactFeedbackGenerator(style: .light)
    private static let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// 预热。进入界面时调一次，第一次点击就没有握手延迟。
    static func prepare() {
        light.prepare()
        softImpact.prepare()
        selection.prepare()
        notification.prepare()
    }

    static func fire(_ kind: HapticKind = .tap) {
        switch kind {
        case .tap:
            light.impactOccurred(intensity: 0.85)
        case .soft:
            softImpact.impactOccurred(intensity: 0.7)
        case .pick:
            selection.selectionChanged()
        case .success:
            notification.notificationOccurred(.success)
        case .warning:
            notification.notificationOccurred(.warning)
        }
        prepare()
    }
}

// MARK: - 玻璃外观

/// 顶层函数：静态面板与按钮样式共用。
/// - tint: 着色（.clear 表示无色玻璃）
/// - tintStrength: 着色浓度（0–1），彩色按钮用高一点
/// - pressed: 按压态，高光更强、阴影更近，模拟液体被挤压
func simulatedGlass(cornerRadius: CGFloat,
                    tint: Color = .clear,
                    tintStrength: Double = 0.45,
                    pressed: Bool = false) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

    return shape
        .fill(.ultraThinMaterial)
        // 着色层：clear 时无效果，蓝/红玻璃也有液体感
        .overlay(
            shape.fill(tint.opacity(pressed ? min(1, tintStrength + 0.10) : tintStrength))
        )
        // 左上斜向流光
        .overlay(
            LinearGradient(
                colors: [Color.white.opacity(pressed ? 0.46 : 0.34),
                         Color.white.opacity(0.08),
                         Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .blendMode(.plusLighter)
            .clipShape(shape)
        )
        // 按压时中间抬起一条高光：镜面随手指位移
        .overlay(
            LinearGradient(
                stops: [
                    .init(color: Color.clear, location: 0),
                    .init(color: Color.white.opacity(pressed ? 0.30 : 0.0), location: 0.32),
                    .init(color: Color.clear, location: 0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
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
        // 高光描边：上亮中弱下回亮
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(pressed ? 0.82 : 0.65), location: 0),
                        .init(color: Color.white.opacity(0.20), location: 0.55),
                        .init(color: Color.white.opacity(pressed ? 0.58 : 0.42), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
        .shadow(color: Color.black.opacity(pressed ? 0.16 : 0.20),
                radius: pressed ? 9 : 14,
                x: 0,
                y: pressed ? 4 : 8)
}

extension View {
    /// 静态玻璃（非交互元素：输入面板、气泡、分隔条、胶囊）
    func glassPanel(cornerRadius: CGFloat) -> some View {
        background { simulatedGlass(cornerRadius: cornerRadius) }
    }
}

// MARK: - 按钮玻璃（可点击元素）

/// 玻璃按钮：材质玻璃背景 + 按压回弹 + 触感反馈。
/// 除了视觉，这里是**所有**按钮触感的唯一来源——按下瞬间触发一次。
struct GlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat
    var tint: Color = .clear
    var tintStrength: Double = 0.45
    var haptic: HapticKind = .tap

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                simulatedGlass(cornerRadius: cornerRadius,
                               tint: tint,
                               tintStrength: tintStrength,
                               pressed: configuration.isPressed)
            }
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .brightness(configuration.isPressed ? 0.03 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed { Haptics.fire(haptic) }
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// 圆形玻璃外圈：给头像这类内容不透明的按钮用。
/// 只在边缘做高光玻璃环，不遮挡里面的照片。
struct GlassRingButtonStyle: ButtonStyle {
    var haptic: HapticKind = .tap
    var lineWidth: CGFloat = 1.4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay(
                Circle().strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(configuration.isPressed ? 1.0 : 0.94), location: 0),
                            .init(color: Color.white.opacity(0.34), location: 0.5),
                            .init(color: Color.white.opacity(configuration.isPressed ? 0.88 : 0.62), location: 1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: configuration.isPressed ? lineWidth + 0.8 : lineWidth
                )
            )
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 4.5)
                    .blur(radius: 1)
            )
            .shadow(color: Color.black.opacity(0.30), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed { Haptics.fire(haptic) }
            }
            .contentShape(Circle())
    }
}

extension View {
    /// 液态玻璃按钮（统一入口）
    /// - tint: 着色，默认无色玻璃；彩色按钮传入蓝/红
    /// - tintStrength: 着色浓度
    /// - haptic: 按下时的触感类型
    func glassButton(cornerRadius: CGFloat,
                     tint: Color = .clear,
                     tintStrength: Double = 0.45,
                     haptic: HapticKind = .tap) -> some View {
        buttonStyle(GlassButtonStyle(cornerRadius: cornerRadius,
                                     tint: tint,
                                     tintStrength: tintStrength,
                                     haptic: haptic))
    }

    /// 圆形玻璃环按钮（头像这类内容不透明的按钮）
    func glassRingButton(haptic: HapticKind = .tap) -> some View {
        buttonStyle(GlassRingButtonStyle(haptic: haptic))
    }
}

// MARK: - 配色

enum Palette {
    static let sendTop = Color(red: 0.36, green: 0.70, blue: 1.0)
    static let sendMid = Color(red: 0.12, green: 0.47, blue: 1.0)
    static let sendBottom = Color(red: 0.02, green: 0.36, blue: 0.92)
    static let hangup = Color(red: 0.90, green: 0.21, blue: 0.17)
}
