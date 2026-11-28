import SwiftUI

// MARK: - 根视图
//
// 结构原则（v20 起）：
// 1. 顶栏用 safeAreaInset 插在消息列表的安全区里：内容顶部内缩（第一条时间胶囊不会被头像压住），
//    但拖动时内容仍能滚到玻璃下面，不再有一条硬裁切线；松手由 ScrollView 自己回弹。
// 2. 玻璃只画在元素自身 bounds 上，全屏绝不包 GlassEffectContainer，
//    否则玻璃形状会被合成错位、画出屏幕。
// 3. 动画只作用于消息列表，避免顶栏/输入区的玻璃跟着整屏重绘。

struct RootView: View {
    @EnvironmentObject private var profile: ProfileModel
    @EnvironmentObject private var chat: ChatModel
    @StateObject private var speech = SpeechRecognizer()

    @State private var draft = ""
    @State private var subject = ""
    @State private var activeSheet: SheetKind?
    @State private var callPresented = false
    @State private var conversationsPresented = false

    enum SheetKind: String, Identifiable {
        case plus, theme, settings
        var id: String { rawValue }
    }

    var body: some View {
        // 页面切换（v22）：
        // 对话列表不再是 fullScreenCover —— 系统 cover 自带一层不透明底，页面和屏幕尺寸
        // 一对不齐就上下露出黑边，而且它必然是整屏推入，背景会跟着一起动。
        // 改成「同一个 ZStack 里换内容」：背景挂在 ZStack 外面且只挂一次，
        // 切页时背景不动，只有内容层用 .opacity 交叉淡出淡入。
        ZStack {
            if conversationsPresented {
                ConversationsScreen(showsBackground: false, onClose: closeConversations)
                    .transition(.opacity)
            } else {
                chatScreen
                    .transition(.opacity)
            }
        }
        // 背景改为 .background 修饰：背景内容不参与布局，
        // 杜绝 scaledToFill 溢出把 ZStack 画布撑大（该模式自 v1 遗留）。
        .background { backgroundLayer }
        // 双保险：把内容硬约束在物理屏幕尺寸内并居中。
        // 若窗口画布被系统/安装工具放大（四周元素被对称裁切的症状），
        // 此处把内容拉回物理屏幕大小；窗口本来正常时是无副作用的空操作。
        .frame(maxWidth: UIScreen.main.bounds.width,
               maxHeight: UIScreen.main.bounds.height)
        .environmentObject(speech)
        .sheet(item: $activeSheet, content: sheetContent)
        .fullScreenCover(isPresented: $callPresented) {
            CallScreen()
        }
    }

    private var chatScreen: some View {
        VStack(spacing: 0) {
            messageList
            Composer(onPlus: { activeSheet = .plus }, draft: $draft, subject: $subject)
        }
    }

    // MARK: - 页面切换

    private func openConversations() {
        Haptics.fire(.tap)
        withAnimation(.easeInOut(duration: 0.28)) { conversationsPresented = true }
    }

    private func closeConversations() {
        withAnimation(.easeInOut(duration: 0.28)) { conversationsPresented = false }
    }

    // MARK: - 背景

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

    // MARK: - 消息列表

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
                    // v26：不再逐字输出。等整段回复攒完，一次性落成气泡；
                    // 等待期间只有这一个三点气泡，不存在两个视图交接的空档帧。
                    if chat.waitingReply {
                        TypingBubble()
                            .id("typing")
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.immediately)
            // 不再给整个 ScrollView 挂 .animation(spring, value: messages)：
            // 它让内容插入和下面的滚动动画各弹一次，两个弹簧打架，就是"一闪一闪"的来源。
            .onAppear { scrollToBottom(proxy) }
            .onChange(of: chat.messages) { _ in scrollToBottom(proxy) }
            .onChange(of: chat.waitingReply) { _ in scrollToBottom(proxy) }
            // 顶栏作为"安全区插入"：布局上占位（首帧就正确，第一条时间胶囊不会被头像压住），
            // 但拖动内容时消息仍能滚到玻璃下面 —— 不再是硬裁切，松手由 ScrollView 自己回弹。
            .safeAreaInset(edge: .top, spacing: 10) {
                TopBar(
                    onBack: openConversations,
                    onVideo: { callPresented = true }
                )
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        let target: AnyHashable? = chat.waitingReply ? "typing" : chat.messages.last?.id
        guard let id = target else { return }

        if animated {
            withAnimation(.easeOut(duration: 0.18)) { proxy.scrollTo(id, anchor: .bottom) }
        } else {
            withTransaction(Transaction(animation: nil)) { proxy.scrollTo(id, anchor: .bottom) }
        }
    }

    private func showsDivider(before index: Int) -> Bool {
        guard index > 0 else { return true }
        return chat.messages[index].time.timeIntervalSince(chat.messages[index - 1].time) > 300
    }

    // MARK: - 弹层

    @ViewBuilder
    private func sheetContent(_ kind: SheetKind) -> some View {
        switch kind {
        case .plus:
            PlusSheet(
                onNewChat: { chat.newChat(); resetDraft(); activeSheet = nil },
                onTheme: { navigate(to: .theme) },
                onSettings: { navigate(to: .settings) },
                onClear: { chat.clearChat(); resetDraft(); activeSheet = nil }
            )
            .presentationDetents([.medium])
        case .theme:
            ThemeSheet()
                .presentationDetents([.medium, .large])
        case .settings:
            SettingsSheet()
                .presentationDetents([.large])
        }
    }

    /// 关闭当前弹层后，等收起动画结束再打开下一个（直接切换会被取消）
    private func navigate(to kind: SheetKind) {
        activeSheet = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            activeSheet = kind
        }
    }

    private func resetDraft() {
        draft = ""
        subject = ""
    }
}

