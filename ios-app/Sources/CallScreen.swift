import SwiftUI

// MARK: - 视频通话全屏页：脉冲波纹 + 计时 + 静音/摄像头/挂断

struct CallScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var profile: ProfileModel

    @State private var connected = false
    @State private var seconds = 0
    @State private var muted = false
    @State private var cameraOff = false
    @State private var pulse = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Spacer()
                ringingAvatar
                Text(profile.name)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                    .padding(.top, 22)
                Text(statusText)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.75))
                    .monospacedDigit()
                    .padding(.top, 8)
                Spacer()
                actions
            }
            .padding(.bottom, 46)
            // 撑满宽度：不然 ZStack 只有内容那么宽，模糊背景也会跟着缩成一条
            .frame(maxWidth: .infinity)
        }
        // 与 RootView 同理：背景不参与布局，避免撑大画布
        .background { background }
        .frame(maxWidth: UIScreen.main.bounds.width,
               maxHeight: UIScreen.main.bounds.height)
        .onReceive(timer) { _ in
            if connected { seconds += 1 }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            connected = true
            // 接通瞬间的"咔哒"反馈
            Haptics.fire(.success)
        }
        .onAppear { pulse = true }
    }

    private var background: some View {
        Image("BgClover")
            .resizable()
            .scaledToFill()
            .ignoresSafeArea()
            .blur(radius: 34)
            .overlay(Color.black.opacity(0.45).ignoresSafeArea())
    }

    private var ringingAvatar: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    .frame(width: 150, height: 150)
                    .scaleEffect(pulse ? 1.42 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .animation(
                        .easeOut(duration: 2.2)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 1.1),
                        value: pulse
                    )
            }
            Group {
                if let image = profile.avatar {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable().scaledToFill()
                        .foregroundColor(.white.opacity(0.85))
                }
            }
            .frame(width: 114, height: 114)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Color.white.opacity(0.9), lineWidth: 2.5))
            .shadow(color: .black.opacity(0.45), radius: 20, y: 10)
        }
    }

    private var statusText: String {
        connected
            ? "通话中 " + String(format: "%02d:%02d", seconds / 60, seconds % 60)
            : "正在呼叫…"
    }

    private var actions: some View {
        HStack(spacing: 34) {
            callButton(icon: muted ? "mic.slash.fill" : "mic.fill",
                       label: muted ? "取消静音" : "静音",
                       iconColor: muted ? Color(white: 0.12) : .white,
                       tint: muted ? .white : .clear,
                       tintStrength: muted ? 0.86 : 0.0,
                       haptic: .pick) { muted.toggle() }

            callButton(icon: cameraOff ? "video.slash.fill" : "video.fill",
                       label: cameraOff ? "打开摄像头" : "摄像头",
                       iconColor: cameraOff ? Color(white: 0.12) : .white,
                       tint: cameraOff ? .white : .clear,
                       tintStrength: cameraOff ? 0.86 : 0.0,
                       haptic: .pick) { cameraOff.toggle() }

            callButton(icon: "phone.down.fill",
                       label: "挂断",
                       iconColor: .white,
                       tint: Palette.hangup,
                       tintStrength: 0.82,
                       haptic: .warning) { dismiss() }
        }
    }

    /// 圆形玻璃图标（66×66，圆角取一半 = 正圆）+ 下面一行文字。
    /// 玻璃只画在图标这块 66×66 上，文字留在玻璃外面 ——
    /// 之前是把整块「图标 + 文字」一起套进 glassButton，玻璃形状跟着 label 一起变高，
    /// 66 宽 × 90 高、圆角 33，就成了一个竖着的长胶囊，看起来像「按键被拉长」。
    private func callButton(icon: String,
                            label: String,
                            iconColor: Color,
                            tint: Color,
                            tintStrength: Double,
                            haptic: HapticKind,
                            action: @escaping () -> Void) -> some View {
        Button {
            Haptics.fire(haptic)
            action()
        } label: {
            VStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(iconColor)
                    .frame(width: 66, height: 66)
                    .glassPanel(cornerRadius: 33, tint: tint, tintStrength: tintStrength)
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.8))
                    .fixedSize()
            }
            // 整块（含下方文字）都能点，但玻璃只有图标那一个圆
            .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle())
    }
}
