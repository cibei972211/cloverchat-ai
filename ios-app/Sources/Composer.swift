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

                if draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    micButton
                } else {
                    sendButton
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .glassPanel(cornerRadius: 22)
    }

    private var micButton: some View {
        Button {
            speech.toggle()
        } label: {
            Image(systemName: "mic.fill")
                .font(.system(size: 16))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
        }
        // 录音中把玻璃染红，状态一眼可见
        .glassButton(cornerRadius: 16,
                     tint: speech.isRecording ? Palette.hangup : .clear,
                     tintStrength: speech.isRecording ? 0.55 : 0.0,
                     haptic: .pick)
        .opacity(speech.isRecording ? 1 : 0.92)
    }

    private var sendButton: some View {
        Button(action: sendMessage) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
        }
        // 蓝色玻璃（原来是实心渐变，v16 换成液体蓝）
        .glassButton(cornerRadius: 16,
                     tint: Palette.sendMid,
                     tintStrength: 0.78,
                     haptic: .soft)
    }

    private func sendMessage() {
        chat.send(text: draft, subject: subject)
        draft = ""
        subject = ""
        speech.stop()
    }
}
