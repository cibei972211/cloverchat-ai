import SwiftUI

// MARK: - 消息气泡 / 时间分隔 / 正在输入

struct MessageBubble: View {
    var message: ChatMessage?
    var liveText: String?

    init(message: ChatMessage) {
        self.message = message
        self.liveText = nil
    }

    init(liveText: String) {
        self.message = nil
        self.liveText = liveText
    }

    private var outgoing: Bool {
        message?.role == .user
    }

    private var text: String {
        message?.text ?? liveText ?? ""
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            if outgoing { Spacer(minLength: 0) }
            bubbleCore
            if !outgoing { Spacer(minLength: 0) }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
    }

    @ViewBuilder
    private var bubbleCore: some View {
        // maxWidth 只封顶不撑开；Spacer(minLength: 0) 保证窄屏不溢出
        let content = VStack(alignment: .leading, spacing: 3) {
            if let subject = message?.subject, !subject.isEmpty {
                Text(subject)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(outgoing ? Color.white.opacity(0.9) : Color.white.opacity(0.72))
            }
            Text(text)
                .font(.system(size: 16.5))
                .lineSpacing(3)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .frame(maxWidth: 300, alignment: .leading)

        if outgoing {
            if #available(iOS 26.0, *) {
                content.glassEffect(
                    .regular.tint(Palette.sendTint),
                    in: RoundedRectangle(cornerRadius: 21, style: .continuous)
                )
            } else {
                content.background(sendBubbleShape)
            }
        } else {
            content.glassPanel(cornerRadius: 21)
        }
    }

    private var sendBubbleShape: some View {
        let shape = RoundedRectangle(cornerRadius: 21, style: .continuous)
        return shape
            .fill(
                LinearGradient(
                    colors: [Palette.sendTop, Palette.sendMid, Palette.sendBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.32), Color.white.opacity(0.06), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottom
                )
                .blendMode(.plusLighter)
                .clipShape(shape)
            )
            .overlay(shape.strokeBorder(Color.white.opacity(0.22), lineWidth: 0.6))
            .shadow(color: Color.blue.opacity(0.30), radius: 13, x: 0, y: 9)
    }
}

// MARK: - 时间分隔玻璃胶囊

struct TimeDivider: View {
    let time: Date

    var body: some View {
        Text(label)
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.white.opacity(0.92))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .glassPanel(cornerRadius: 13)
            .padding(.vertical, 4)
    }

    var label: String {
        let formatter = DateFormatter()
        let now = Calendar.current.startOfDay(for: Date())
        let day = Calendar.current.startOfDay(for: time)
        let base: String
        if day == now {
            base = "今天"
        } else if day == Calendar.current.date(byAdding: .day, value: -1, to: now) {
            base = "昨天"
        } else {
            formatter.dateFormat = "M月d日"
            base = formatter.string(from: time)
        }
        formatter.dateFormat = "HH:mm"
        return base + " " + formatter.string(from: time)
    }
}

// MARK: - 正在输入（三点跳动）

struct TypingBubble: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 7, height: 7)
                        .offset(y: animating ? -4 : 0)
                        .opacity(animating ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.16),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 17)
            .padding(.vertical, 15)
            .glassPanel(cornerRadius: 21)
            Spacer(minLength: 0)
        }
        .onAppear { animating = true }
    }
}
