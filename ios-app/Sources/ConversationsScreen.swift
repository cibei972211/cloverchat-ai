import SwiftUI

// MARK: - 对话列表页（返回按钮进入）
//
// 结构：返回 → 标题 → 搜索框 → 新建对话 → 所有对话（当前 + 历史，可删）
// 数据：ChatModel.conversations 归档历史，chat.currentSummary 是正在进行的这一段。

struct ConversationsScreen: View {
    /// true：自己画背景（独立使用）。false：嵌在 RootView 里，共用根背景（切页时背景不动）。
    var showsBackground: Bool = true
    /// 关闭回调。嵌在根视图里时不能用 @Environment(\.dismiss)，走这里。
    var onClose: () -> Void = {}

    @EnvironmentObject private var profile: ProfileModel
    @EnvironmentObject private var chat: ChatModel

    @State private var query = ""

    private var history: [Conversation] {
        chat.conversations.filter { $0.matches(query) }
    }

    private var currentRow: Conversation? {
        guard let current = chat.currentSummary else { return nil }
        return current.matches(query) ? current : nil
    }

    private var isEmpty: Bool {
        currentRow == nil && history.isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            header
            searchBar
                .padding(.horizontal, 16)
            list
        }
        .padding(.top, 6)
        // 背景必须走 .background 修饰（不参与布局）。
        // 之前把它当 ZStack 子视图：scaledToFill 的图片把画布撑大，
        // 整页被放大居中、左右各裁掉一截 —— 表现就是按钮被拉长、标题和时间跑出屏幕。
        .background {
            if showsBackground {
                backgroundLayer
            } else {
                // 嵌在根视图里：背景交给 RootView 不动，这层只是随内容淡入的轻微压暗
                LinearGradient(
                    colors: [Color.black.opacity(0.18),
                             Color.black.opacity(0.10),
                             Color.black.opacity(0.20)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
        }
        // 与 RootView / CallScreen 同样的兜底：硬约束在物理屏幕内
        .frame(maxWidth: UIScreen.main.bounds.width,
               maxHeight: UIScreen.main.bounds.height)
        .clipped()
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
                colors: [Color.black.opacity(0.46),
                         Color.black.opacity(0.26),
                         Color.black.opacity(0.52)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var themeImage: String {
        switch profile.themeID {
        case "dusk": return "BgDusk"
        case "night": return "BgNight"
        default: return "BgClover"
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.fire(.tap)
                onClose()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 42)
            }
            .glassButton(cornerRadius: 21)

            Text("对话")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Text("\(chat.conversations.count) 段")
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.55))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 搜索

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.62))

            TextField("搜索对话", text: $query)
                .font(.system(size: 15))
                .foregroundColor(.white)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !query.isEmpty {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Haptics.fire(.pick)
                        query = ""
                    }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .glassPanel(cornerRadius: 18)
    }

    // MARK: - 列表

    private var list: some View {
        ScrollView {
            VStack(spacing: 10) {
                Button {
                    Haptics.fire(.soft)
                    chat.newChat()
                    onClose()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Text("新建对话")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .glassButton(cornerRadius: 17,
                             tint: Palette.sendMid,
                             tintStrength: 0.50,
                             haptic: .soft)

                HStack {
                    Text("所有对话")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.68))
                    Spacer()
                    if !query.isEmpty {
                        Text("匹配 \(history.count + (currentRow == nil ? 0 : 1)) 条")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.45))
                    }
                }
                .padding(.top, 6)
                .padding(.horizontal, 2)

                if let current = currentRow {
                    row(current, isCurrent: true)
                }

                ForEach(history) { conversation in
                    row(conversation, isCurrent: false)
                }

                if isEmpty {
                    emptyState
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 26)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func row(_ conversation: Conversation, isCurrent: Bool) -> some View {
        Button {
            guard !isCurrent else {
                onClose()
                return
            }
            Haptics.fire(.pick)
            chat.open(conversation)
            onClose()
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.white.opacity(0.14))
                    Image(systemName: isCurrent ? "bubble.left.fill" : "clock.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(conversation.title)
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        if isCurrent {
                            Text("当前")
                                .font(.system(size: 10.5, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Palette.sendMid.opacity(0.85),
                                            in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    Text(conversation.preview)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(timeLabel(conversation.updatedAt))
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.45))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassButton(cornerRadius: 16, haptic: .pick)
        .contextMenu {
            if !isCurrent {
                Button(role: .destructive) {
                    Haptics.fire(.warning)
                    chat.delete(conversation)
                } label: {
                    Label("删除对话", systemImage: "trash")
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 9) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundColor(.white.opacity(0.38))
            Text(query.isEmpty ? "还没有其他对话" : "没有找到相关对话")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }

    private func timeLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}
