import SwiftUI

// MARK: - 根视图
//
// 结构原则（已验证可用的布局）：
// 1. ZStack 叠放：背景 → 消息列表（按运行时测量的顶栏/输入栏高度避让）
//    → 顶栏（顶部固定）→ 输入区（底部固定）。
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
    @State private var topBarHeight: CGFloat = 0
    @State private var composerHeight: CGFloat = 0

    enum SheetKind: String, Identifiable {
        case plus, theme, settings, history
        var id: String { rawValue }
    }

    var body: some View {
        ZStack {
            messageList
                .padding(.top, topBarHeight + 10)
                .padding(.bottom, composerHeight)
            VStack(spacing: 0) {
                TopBar(
                    onBack: { activeSheet = .history },
                    onVideo: { callPresented = true }
                )
                .measureSize { topBarHeight = $0.height }
                Spacer(minLength: 0)
            }
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Composer(onPlus: { activeSheet = .plus }, draft: $draft, subject: $subject)
                    .measureSize { composerHeight = $0.height }
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
                    if chat.waitingReply {
                        TypingBubble()
                            .id("typing")
                    }
                    if chat.liveActive {
                        MessageBubble(liveText: chat.liveText)
                            .id("live")
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 12)
                .padding(.horizontal, 16)
            }
            .scrollDismissesKeyboard(.immediately)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: chat.messages)
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
        case .history:
            HistorySheet(
                onNewChat: { chat.newChat(); resetDraft(); activeSheet = nil },
                onClear: { chat.clearChat(); resetDraft(); activeSheet = nil }
            )
            .presentationDetents([.medium])
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

// MARK: - 运行时测量视图尺寸（iOS 16 兼容）
// 用 PreferenceKey 读取顶栏/输入栏的实际高度，消息列表据此避让，
// 替代写死的魔术数字，保证任意机型比例正确。

private struct SizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

extension View {
    func measureSize(_ onChange: @escaping (CGSize) -> Void) -> some View {
        background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: SizePreferenceKey.self, value: geo.size)
            }
        )
        .onPreferenceChange(SizePreferenceKey.self) { size in
            onChange(size)
        }
    }
}
