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
                    .onSubmit(sendMessage)
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
                .foregroundColor(speech.isRecording ? Color(red: 1.0, green: 0.42, blue: 0.38) : .white)
                .frame(width: 30, height: 30)
        }
        .opacity(speech.isRecording ? 1 : 0.9)
    }

    private var sendButton: some View {
        Button(action: sendMessage) {
            Image(systemName: "arrow.up")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(
                        LinearGradient(
                            colors: [Palette.sendTop, Palette.sendBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
                .shadow(color: Color.blue.opacity(0.35), radius: 6, y: 3)
        }
    }

    private func sendMessage() {
        chat.send(text: draft, subject: subject)
        draft = ""
        subject = ""
        speech.stop()
    }
}
