import SwiftUI

struct RootView: View {
    @EnvironmentObject private var profile: ProfileModel
    @EnvironmentObject private var chat: ChatModel
    @StateObject private var speech = SpeechRecognizer()

    @State private var draft = ""
    @State private var subject = ""
    @State private var activeSheet: SheetKind?
    @State private var callPresented = false
    @FocusState private var inputFocused: Bool

    enum SheetKind: String, Identifiable {
        case plus, settings, theme, history
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            backgroundLayer
            messageList
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                composer
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: chat.messages)
        .sheet(item: $activeSheet) { kind in
            sheetContent(kind)
        }
        .fullScreenCover(isPresented: $callPresented) {
            CallScreen()
        }
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        Group {
            if profile.themeID == "custom", let image = profile.customBackground {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(themeImage).resizable().scaledToFill()
            }
        }
        .ignoresSafeArea()
        .overlay(
            LinearGradient(
                colors: [Color.black.opacity(0.30), Color.clear, Color.clear, Color.black.opacity(0.38)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .overlay(Color.black.opacity(0.06).ignoresSafeArea())
        .id(profile.themeID)
    }

    private var themeImage: String {
        switch profile.themeID {
        case "dusk": return "BgDusk"
        case "night": return "BgNight"
        default: return "BgClover"
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        ZStack {
            HStack(alignment: .top) {
                backButton
                Spacer()
                videoButton
            }
            VStack(spacing: 9) {
                avatarButton
                namePill
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var backButton: some View {
        Button {
            activeSheet = .history
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(width: 44, height: 42)
        }
        .glassPanel(cornerRadius: 21)
    }

    private var videoButton: some View {
        Button {
            callPresented = true
        } label: {
            Image(systemName: "video.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
        }
        .glassPanel(cornerRadius: 21)
    }

    private var avatarButton: some View {
        Button {
            activeSheet = .history
        } label: {
            avatarImage
                .frame(width: 60, height: 60)
        }
    }

    private var avatarImage: some View {
        Group {
            if let image = profile.avatar {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFill()
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.95), lineWidth: 2.5))
        .overlay(Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 4.5).blur(radius: 1))
        .shadow(color: .black.opacity(0.32), radius: 12, y: 6)
    }

    private var namePill: some View {
        HStack(spacing: 4) {
            Text(profile.name)
                .font(.system(size: 16, weight: .semibold))
                .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.72))
        }
        .padding(.leading, 15)
        .padding(.trailing, 9)
        .frame(height: 33)
        .foregroundColor(.white)
        .glassPanel(cornerRadius: 17)
    }

    // MARK: - Messages

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(chat.messages.enumerated()), id: \.element.id) { index, message in
                        if showsDivider(before: index) {
                            TimeDivider(time: message.time)
                                .padding(.vertical, 2)
                        }
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    if chat.waitingReply {
                        TypingBubble()
                            .id("typing")
                    }
                    if chat.liveActive {
                        MessageBubble(liveText: chat.liveText)
                            .id("live")
                    }
                }
                .padding(.top, 118)
                .padding(.bottom, 135)
                .padding(.horizontal, 16)
            }
            .simultaneousGesture(DragGesture().onChanged { _ in inputFocused = false })
            .onAppear { scrollToBottom(proxy) }
            .onChange(of: chat.messages) { _ in scrollToBottom(proxy) }
            .onChange(of: chat.liveText) { _ in scrollToBottom(proxy, animated: false) }
            .onChange(of: chat.waitingReply) { _ in scrollToBottom(proxy) }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let target: AnyHashable?
        if chat.waitingReply {
            target = "typing"
        } else if chat.liveActive {
            target = "live"
        } else {
            target = chat.messages.last?.id
        }
        guard let id = target else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) { proxy.scrollTo(id, anchor: .bottom) }
        } else {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }

    private func showsDivider(before index: Int) -> Bool {
        guard index > 0 else { return true }
        return chat.messages[index].time.timeIntervalSince(chat.messages[index - 1].time) > 300
    }

    // MARK: - Composer

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            plusButton
            inputPanel
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    private var plusButton: some View {
        Button {
            activeSheet = .plus
            inputFocused = false
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 19, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 47, height: 47)
        }
        .glassPanel(cornerRadius: 24)
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("主题", text: $subject)
                .font(.system(size: 15.5))
                .foregroundColor(.white.opacity(0.95))
                .padding(.horizontal, 4)
                .frame(height: 26)
                .submitLabel(.next)
                .onSubmit { inputFocused = true }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.38), Color.white.opacity(0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 0.8)

            HStack(alignment: .bottom, spacing: 6) {
                TextField("iMessage信息", text: $draft, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .submitLabel(.send)
                    .onSubmit(sendMessage)
                    .padding(.vertical, 7)

                if draft.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button {
                        speech.toggle()
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 16))
                            .foregroundColor(speech.isRecording ? Color(red: 1.0, green: 0.42, blue: 0.38) : .white)
                            .frame(width: 30, height: 32)
                    }
                    .opacity(speech.isRecording ? 1 : 0.9)
                } else {
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
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 9)
        .padding(.bottom, 7)
        .glassPanel(cornerRadius: 30)
        .onChange(of: speech.transcript) { text in
            if speech.isRecording { draft = text }
        }
        .onChange(of: speech.isRecording) { recording in
            if !recording { _ = speech.transcript }
        }
    }

    private func sendMessage() {
        chat.send(text: draft, subject: subject)
        draft = ""
        subject = ""
        speech.stop()
    }

    // MARK: - Sheets

    @ViewBuilder
    private func sheetContent(_ kind: SheetKind) -> some View {
        switch kind {
        case .plus:
            PlusSheet { next in
                activeSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    activeSheet = next
                }
            }
            .presentationDetents([.medium])
        case .settings:
            SettingsSheet()
                .presentationDetents([.large])
        case .theme:
            ThemeSheet()
                .presentationDetents([.medium, .large])
        case .history:
            HistorySheet { next in
                activeSheet = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    activeSheet = next
                }
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Bubbles

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
            if outgoing { Spacer(minLength: 60) }
            VStack(alignment: outgoing ? .trailing : .leading, spacing: 3) {
                if let subject = message?.subject, !subject.isEmpty {
                    Text(subject)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 6)
                }
                Text(text)
                    .font(.system(size: 16.5))
                    .lineSpacing(3)
                    .foregroundColor(.white)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(outgoing ? AnyView(sendBubbleShape) : AnyView(glassBubbleShape))
            }
            .frame(maxWidth: 310, alignment: outgoing ? .trailing : .leading)
            if !outgoing { Spacer(minLength: 60) }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        ))
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

    private var glassBubbleShape: some View {
        let shape = RoundedRectangle(cornerRadius: 21, style: .continuous)
        return shape
            .fill(.ultraThinMaterial)
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.26), Color.white.opacity(0.05), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottom
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
            .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
    }
}

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

    private var label: String {
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
            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
    }
}
