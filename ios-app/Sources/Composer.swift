import SwiftUI

// MARK: - 底部输入区：加号（47×47 玻璃）+ 主题/信息面板 + 麦克风/发送

struct Composer: View {
    @EnvironmentObject private var chat: ChatModel
    @EnvironmentObject private var speech: SpeechRecognizer

    let onPlus: () -> Void
    @Binding var draft: String
    @Binding var subject: String

    @FocusState private var inputFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            plusButton
            inputPanel
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        .onChange(of: speech.transcript) { text in
            if speech.isRecording { draft = text }
        }
    }

    private var plusButton: some View {
        Button {
            inputFocused = false
            onPlus()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 47, height: 47)
        }
        .glassButton(cornerRadius: 24)
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("主题", text: $subject)
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.92))
                .padding(.horizontal, 2)
                .frame(height: 24)
                .submitLabel(.next)
                .onSubmit { inputFocused = true }

            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(height: 0.8)
                .padding(.horizontal, 2)

            HStack(alignment: .bottom, spacing: 6) {
                TextField("iMessage信息", text: $draft, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    // 键盘上的"发送"也给一次触感，和点按钮一致
                    .onSubmit {
                        Haptics.fire(.soft)
                        sendMessage()
                    }
                    .padding(.vertical, 6)

                // 一个按钮，两种形态（v23）。
                // 原来是 mic 和 send 两个 Button 交替出现：每次发完消息 draft 变空，
                // 两层原生玻璃被拆掉重建，就是一整下闪。现在只有一颗玻璃，换图标和着色。
                actionButton
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .glassPanel(cornerRadius: 22)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var actionButton: some View {
        Button {
            if canSend {
                sendMessage()
            } else {
                speech.toggle()
            }
        } label: {
            Image(systemName: speech.isRecording
                  ? "waveform"
                  : (canSend ? "arrow.up" : "mic.fill"))
                .font(.system(size: canSend ? 15 : 16, weight: canSend ? .bold : .regular))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
        }
        // 录音中染红，有内容时是蓝色玻璃，空时为无色玻璃
        .glassButton(cornerRadius: 16,
                     tint: speech.isRecording ? Palette.hangup : (canSend ? Palette.sendMid : .clear),
                     tintStrength: speech.isRecording ? 0.55 : (canSend ? 0.78 : 0.0),
                     haptic: .soft)
        .opacity(speech.isRecording || canSend ? 1 : 0.92)
    }

    private func sendMessage() {
        chat.send(text: draft, subject: subject)
        draft = ""
        subject = ""
        speech.stop()
    }
}
