import SwiftUI
import UIKit

// MARK: - 全局开关（v17：真液态玻璃）
//
// iOS 26+ 走系统原生 Liquid Glass（.glassEffect 真玻璃：折射、镜面、按压液体形变）；
// 低于 iOS 26 自动退回材质高仿（v12 方案，已验证可用）。
//
// 历史：v13–v15 在实机上出现过"玻璃盖住的按钮收不到触摸"。所以保留这个总开关：
// 若实机上按钮又点不动，把 useNative 改成 false 即可立刻回到材质方案，其它代码不用动。

enum GlassConfig {
    static let useNative = true
}

// MARK: - 触感反馈

/// 反馈类型：按钮按下 / 轻触 / 选择 / 成功 / 警告
enum HapticKind {
    case tap        // 普通按钮按下
    case soft       // 轻触发：发送、切换
    case pick       // 选择类：主题、列表
    case success    // 确认成功
    case warning    // 危险操作、失败
}

/// 统一触感入口。用 UIFeedbackGenerator（iOS 16 兼容，不依赖 iOS 17 的 .sensoryFeedback）。
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

// MARK: - 原生液态玻璃（iOS 26+）

/// 统一构造原生玻璃：可着色 + 可交互（按压时有液体形变与高光回应）
@available(iOS 26.0, *)
func nativeGlass(tint: Color, strength: Double, interactive: Bool) -> Glass {
    let tinted = Glass.regular.tint(tint.opacity(strength))
    return interactive ? tinted.interactive() : tinted
}

/// 原生玻璃按钮：玻璃画在 label 上（Apple 推荐的位置），按压动画与触感由本样式负责
@available(iOS 26.0, *)
struct NativeGlassButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat
    var tint: Color = .clear
    var tintStrength: Double = 0.0
    var haptic: HapticKind = .tap

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .glassEffect(nativeGlass(tint: tint, strength: tintStrength, interactive: true),
                         in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed { Haptics.fire(haptic) }
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// 原生玻璃外圈：头像这类内容不透明的按钮，玻璃比内容大一圈，露出真实的折射边缘
@available(iOS 26.0, *)
struct NativeGlassRingButtonStyle: ButtonStyle {
    var haptic: HapticKind = .tap

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(3)
            .glassEffect(.regular.interactive(), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed { Haptics.fire(haptic) }
            }
            .contentShape(Circle())
    }
}

// MARK: - 材质回退（iOS 16+）

/// 顶层函数：材质玻璃，静态面板与按钮样式共用。
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
        .overlay(
            shape.fill(tint.opacity(pressed ? min(1, tintStrength + 0.10) : tintStrength))
        )
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
        .overlay(
            LinearGradient(
                colors: [Color.clear, Color.white.opacity(0.10)],
                startPoint: .center,
                endPoint: .bottom
            )
            .blendMode(.plusLighter)
            .clipShape(shape)
        )
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

/// 材质玻璃按钮（iOS 26 以下，或关掉开关时使用）
struct MaterialGlassButtonStyle: ButtonStyle {
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

/// 材质玻璃外圈（头像用）
struct MaterialGlassRingButtonStyle: ButtonStyle {
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

// MARK: - 统一入口

extension View {
    /// 静态玻璃面板（非交互元素：输入面板、气泡、分隔条、胶囊、圆形按键底）
    /// - tint/tintStrength：可选着色，圆形通话键这类需要白色/红色玻璃时用
    @ViewBuilder
    func glassPanel(cornerRadius: CGFloat,
                    tint: Color = .clear,
                    tintStrength: Double = 0.0) -> some View {
        if #available(iOS 26.0, *), GlassConfig.useNative {
            glassEffect(nativeGlass(tint: tint, strength: tintStrength, interactive: false),
                        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            background { simulatedGlass(cornerRadius: cornerRadius,
                                        tint: tint,
                                        tintStrength: tintStrength) }
        }
    }

    /// 液态玻璃按钮（统一入口）
    /// - tint: 着色，默认无色玻璃；发送/挂断这类传蓝/红
    /// - tintStrength: 着色浓度
    /// - haptic: 按下时的触感类型
    @ViewBuilder
    func glassButton(cornerRadius: CGFloat,
                     tint: Color = .clear,
                     tintStrength: Double = 0.45,
                     haptic: HapticKind = .tap) -> some View {
        if #available(iOS 26.0, *), GlassConfig.useNative {
            buttonStyle(NativeGlassButtonStyle(cornerRadius: cornerRadius,
                                               tint: tint,
                                               tintStrength: tintStrength,
                                               haptic: haptic))
        } else {
            buttonStyle(MaterialGlassButtonStyle(cornerRadius: cornerRadius,
                                                 tint: tint,
                                                 tintStrength: tintStrength,
                                                 haptic: haptic))
        }
    }

    /// 圆形玻璃环按钮（头像这类内容不透明的按钮）
    @ViewBuilder
    func glassRingButton(haptic: HapticKind = .tap) -> some View {
        if #available(iOS 26.0, *), GlassConfig.useNative {
            buttonStyle(NativeGlassRingButtonStyle(haptic: haptic))
        } else {
            buttonStyle(MaterialGlassRingButtonStyle(haptic: haptic))
        }
    }
}

// MARK: - 只做按压反馈的按钮样式（玻璃由元素自己画，通常用在"图标一块玻璃 + 下方文字"的按键）

/// 通话页那种「圆形玻璃图标 + 下面一行文字」的按键：
/// 玻璃只能盖住图标本身，不能连文字一起包进去 —— 否则玻璃会被拉成竖着的长胶囊。
/// 所以这里不用 glassButton（它会把整块 label 包上玻璃），只保留按压缩放，触感在 action 里自己发。
struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - 配色

enum Palette {
    static let sendTop = Color(red: 0.36, green: 0.70, blue: 1.0)
    static let sendMid = Color(red: 0.12, green: 0.47, blue: 1.0)
    static let sendBottom = Color(red: 0.02, green: 0.36, blue: 0.92)
    static let hangup = Color(red: 0.90, green: 0.21, blue: 0.17)
}
