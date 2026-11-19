import PhotosUI
import SwiftUI

// MARK: - 弹层共享行样式

private func sheetRow(icon: String,
                      tint: Color,
                      title: String,
                      destructive: Bool = false,
                      action: @escaping () -> Void) -> some View {
    Button(action: action) {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 37, height: 37)
                .background(tint.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(title)
                .font(.system(size: 16.5))
                .foregroundColor(destructive ? Color(red: 1.0, green: 0.54, blue: 0.5) : .white)
            Spacer()
        }
        .padding(10)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
}

// MARK: - 加号菜单

struct PlusSheet: View {
    let onNewChat: () -> Void
    let onTheme: () -> Void
    let onSettings: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Text("操作")
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 10)

            sheetRow(icon: "plus.bubble.fill", tint: .green, title: "新对话", action: onNewChat)
            sheetRow(icon: "photo.on.rectangle", tint: .blue, title: "聊天背景", action: onTheme)
            sheetRow(icon: "gearshape.fill", tint: .gray, title: "AI 设置", action: onSettings)
            Divider().overlay(Color.white.opacity(0.12)).padding(.vertical, 6)
            sheetRow(icon: "trash.fill", tint: .red, title: "清空对话", destructive: true, action: onClear)
        }
        .padding(18)
        .padding(.bottom, 6)
    }
}

// MARK: - 聊天背景

struct ThemeSheet: View {
    @EnvironmentObject private var profile: ProfileModel
    @Environment(\.dismiss) private var dismiss
    @State private var pickerItem: PhotosPickerItem?

    private let themes: [(id: String, name: String, image: String)] = [
        ("clover", "三叶草", "BgClover"),
        ("dusk", "黄昏", "BgDusk"),
        ("night", "星夜", "BgNight"),
    ]

    var body: some View {
        VStack(spacing: 14) {
            Text("聊天背景")
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                ForEach(themes, id: \.id) { theme in
                    tile(id: theme.id, name: theme.name) {
                        Image(theme.image).resizable().scaledToFill()
                    }
                    .onTapGesture {
                        profile.themeID = theme.id
                        dismiss()
                    }
                }
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    tile(id: "custom", name: profile.customBackground != nil ? "我的图片" : "上传图片") {
                        if let image = profile.customBackground {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            ZStack {
                                LinearGradient(colors: [Color.white.opacity(0.16), Color.white.opacity(0.05)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 2)

            Text("选一张喜欢的图，或从相册上传自己的背景")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(18)
        .onChange(of: pickerItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    profile.saveBackground(data)
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private func tile(id: String, name: String, @ViewBuilder content: () -> some View) -> some View {
        let selected = profile.themeID == id
        content()
            .aspectRatio(0.66, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(
                        selected ? AnyShapeStyle(Color.white) : AnyShapeStyle(Color.white.opacity(0.2)),
                        lineWidth: selected ? 2.5 : 0.8
                    )
            )
            .overlay(
                VStack {
                    Spacer()
                    Text(name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 3)
                        .padding(.bottom, 6)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
                        )
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 10, y: 6)
    }
}

// MARK: - 个性化 / AI 设置

struct SettingsSheet: View {
    @EnvironmentObject private var profile: ProfileModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var baseUrl = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var avatarItem: PhotosPickerItem?
    @State private var initialized = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("个性化")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 2)

                HStack(spacing: 14) {
                    PhotosPicker(selection: $avatarItem, matching: .images) {
                        Group {
                            if let image = profile.avatar {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .resizable().scaledToFill()
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .frame(width: 58, height: 58)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 2))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("头像与名字")
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundColor(.white)
                        Text("点按头像从相册选择新图片")
                            .font(.system(size: 12.5))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                }
                .padding(4)

                field("对方的名字", placeholder: "例如：小树", text: $name, keyboard: .default)
                    .padding(.top, 2)

                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.8).padding(.vertical, 4)

                field("AI 接口地址（可选）", placeholder: "https://api.openai.com/v1", text: $baseUrl, keyboard: .URL)
                field("API Key（可选）", placeholder: "sk-...", text: $apiKey, keyboard: .default, secure: true)
                field("模型", placeholder: "gpt-4o-mini", text: $model, keyboard: .default)

                Text("兼容 OpenAI Chat Completions 接口；接口地址留空则使用内置模式。头像、名字与设置只保存在本机。")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 2)

                Button(action: save) {
                    Text("保存")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            LinearGradient(
                                colors: [Palette.sendTop, Palette.sendMid, Palette.sendBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                        .shadow(color: Color.blue.opacity(0.35), radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Button {
                    profile.resetProfile()
                    name = profile.name
                    dismiss()
                } label: {
                    Text("恢复默认头像和名字")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .glassButton(cornerRadius: 16)
            }
            .padding(18)
            .padding(.bottom, 8)
        }
        .onAppear {
            guard !initialized else { return }
            initialized = true
            name = profile.name
            baseUrl = profile.apiConfig.baseUrl
            apiKey = profile.apiConfig.apiKey
            model = profile.apiConfig.model
        }
        .onChange(of: avatarItem) { item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    profile.saveAvatar(data)
                }
            }
        }
    }

    private func save() {
        let trimmedBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBase.isEmpty && !trimmedBase.lowercased().hasPrefix("http://") && !trimmedBase.lowercased().hasPrefix("https://") {
            return
        }
        profile.name = String(name.trimmingCharacters(in: .whitespaces).prefix(12))
        profile.apiConfig = APIConfig(
            baseUrl: trimmedBase,
            apiKey: apiKey.trimmingCharacters(in: .whitespacesAndNewlines),
            model: model.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
    }

    private func field(_ title: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.system(size: 16))
            .foregroundColor(.white)
            .keyboardType(keyboard)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
            )
        }
    }
}

// MARK: - 消息 / 历史

struct HistorySheet: View {
    @EnvironmentObject private var profile: ProfileModel
    @EnvironmentObject private var chat: ChatModel

    let onNewChat: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("消息")
                .font(.system(size: 17, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.bottom, 6)

            HStack(spacing: 12) {
                avatar(size: 50)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(profile.name)
                            .font(.system(size: 16.5, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Text(timeLabel)
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.45))
                    }
                    Text(preview)
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .padding(10)

            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.8).padding(.vertical, 4)

            sheetRow(icon: "plus.bubble.fill", tint: .blue, title: "开始新对话", action: onNewChat)
            sheetRow(icon: "trash.fill", tint: .red, title: "清空对话", destructive: true, action: onClear)
                .opacity(chat.messages.isEmpty ? 0.45 : 1)
                .disabled(chat.messages.isEmpty)

            Text("消息保存在这台设备上")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.45))
                .padding(.top, 8)
        }
        .padding(18)
        .padding(.bottom, 6)
    }

    private var preview: String {
        if let last = chat.messages.last {
            let prefix = last.role == .user ? "你：" : ""
            return prefix + last.text.replacingOccurrences(of: "\n", with: " ")
        }
        return "在等你"
    }

    private var timeLabel: String {
        guard let last = chat.messages.last else { return "刚刚" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: last.time)
    }

    private func avatar(size: CGFloat) -> some View {
        Group {
            if let image = profile.avatar {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFill()
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5))
    }
}
