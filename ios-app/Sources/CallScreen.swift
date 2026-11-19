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
            background
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
        }
        .onReceive(timer) { _ in
            if connected { seconds += 1 }
        }
        .task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            connected = true
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
        HStack(spacing: 36) {
            callButton(icon: muted ? "mic.slash.fill" : "mic.fill",
                       label: muted ? "取消静音" : "静音",
                       active: muted) { muted.toggle() }
            callButton(icon: cameraOff ? "video.slash.fill" : "video.fill",
                       label: cameraOff ? "打开摄像头" : "摄像头",
                       active: cameraOff) { cameraOff.toggle() }
            Button {
                dismiss()
            } label: {
                VStack(spacing: 9) {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 66, height: 66)
                        .background(
                            Circle().fill(
                                LinearGradient(
                                    colors: [Color(red: 1.0, green: 0.42, blue: 0.37), Color(red: 0.9, green: 0.21, blue: 0.17)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                        .shadow(color: Color.red.opacity(0.45), radius: 14, y: 8)
                    Text("挂断")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func callButton(icon: String, label: String, active: Bool, action: @escaping () -> Void) -> some View {
        let buttonLabel = VStack(spacing: 9) {
            callIcon(icon: icon, active: active)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
        }
        if active {
            Button(action: action) { buttonLabel }
                .buttonStyle(.plain)
        } else {
            Button(action: action) { buttonLabel }
                .buttonStyle(GlassButtonStyle(cornerRadius: 33))
        }
    }

    @ViewBuilder
    private func callIcon(icon: String, active: Bool) -> some View {
        let icon = Image(systemName: icon)
            .font(.system(size: 21, weight: .semibold))
            .foregroundColor(active ? Color(white: 0.12) : .white)
            .frame(width: 66, height: 66)
        if active {
            icon
                .background(Circle().fill(Color.white.opacity(0.94)))
        } else {
            icon
        }
    }
}
