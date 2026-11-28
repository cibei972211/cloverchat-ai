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
    }
    // 列表行也是按钮：给玻璃 + 按下触感；危险操作换成警告反馈
    .glassButton(cornerRadius: 14, haptic: destructive ? .warning : .pick)
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
                        Haptics.fire(.pick)
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
            Haptics.fire(.pick)
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
            // 玻璃面：左上流光 + 底缘反光，读起来像一块玻璃压着照片
            .overlay(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.32), location: 0),
                                .init(color: Color.clear, location: 0.42),
                                .init(color: Color.white.opacity(0.14), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottom
                        )
                    )
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
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
    @State private var prompt = ""
    @State private var delaySeconds: Double = 0
    @State private var appName = ""
    @State private var iconItem: PhotosPickerItem?
    @State private var cropTarget: CropTarget?
    @State private var avatarItem: PhotosPickerItem?
    @State private var initialized = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(spacing: 3) {
                    Text("个性化")
                        .font(.system(size: 17, weight: .bold))
                    Text(profile.appName)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.45))
                }
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

                Text("应用外观")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))

                field("应用名称", placeholder: "例如：小树", text: $appName, keyboard: .default)

                HStack(spacing: 14) {
                    iconPreview
                    VStack(alignment: .leading, spacing: 4) {
                        Text("应用图标")
                            .font(.system(size: 15.5, weight: .semibold))
                            .foregroundColor(.white)
                        Text("从相册选图，自己拖动缩放裁剪")
                            .font(.system(size: 12.5))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    PhotosPicker(selection: $iconItem, matching: .images) {
                        Text("更换")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 62, height: 36)
                    }
                    .glassButton(cornerRadius: 12, haptic: .pick)
                }
                .padding(4)

                if profile.customIcon != nil {
                    HStack(spacing: 10) {
                        if let url = iconExportFile {
                            ShareLink(item: url) {
                                HStack(spacing: 5) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("导出这张图标")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .background(Color.white.opacity(0.13),
                                            in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                            }
                        }
                        Button {
                            Haptics.fire(.warning)
                            profile.resetIcon()
                        } label: {
                            Text("恢复默认图标")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                        }
                        .glassButton(cornerRadius: 11, haptic: .warning)
                        Spacer()
                    }
                }

                Text("桌面上的名字和图标由安装包决定，iOS 不允许 App 在运行时改。这里改的是 App 内的称呼；裁好的图标会存在本机、可以导出，把它打进下一版安装包，桌面才会跟着变。")
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.45))
                    .lineSpacing(2)

                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.8).padding(.vertical, 4)

                field("AI 接口地址（可选）", placeholder: "https://api.openai.com/v1", text: $baseUrl, keyboard: .URL)
                field("API Key（可选）", placeholder: "sk-...", text: $apiKey, keyboard: .default, secure: true)
                field("模型", placeholder: "gpt-4o-mini", text: $model, keyboard: .default)

                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.8).padding(.vertical, 4)

                promptEditor

                delayRow

                Text("提示词就是你自己的设定，原样作为 system 消息发送。留空就完全不发送，模型按接口原始行为回复 —— 内置人设已经去掉了。头像、名字与设置只保存在本机。")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.top, 2)

                Button(action: save) {
                    Text("保存")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                // 蓝色液体玻璃（原来是实心渐变）
                .glassButton(cornerRadius: 16,
                             tint: Palette.sendMid,
                             tintStrength: 0.78)
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
            prompt = profile.systemPrompt
            delaySeconds = profile.replyDelaySeconds
            appName = profile.appName
        }
        .onChange(of: avatarItem) { item in
            guard let item else { return }
            Haptics.fire(.pick)
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    profile.saveAvatar(data)
                }
            }
        }
        .onChange(of: iconItem) { item in
            guard let item else { return }
            Haptics.fire(.pick)
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    cropTarget = CropTarget(image: image)
                }
            }
        }
        .sheet(item: $cropTarget) { target in
            IconCropper(image: target.image,
                        onCancel: { cropTarget = nil },
                        onDone: { image in
                            profile.saveIcon(image)
                            cropTarget = nil
                        })
        }
    }

    /// 图标预览：有自定义就用它，否则用默认的三叶草占位
    private var iconPreview: some View {
        Group {
            if let icon = profile.customIcon {
                Image(uiImage: icon).resizable().scaledToFill()
            } else {
                ZStack {
                    LinearGradient(colors: [Color.white.opacity(0.20), Color.white.opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1.5)
        )
    }

    /// 导出一个临时 png，给 ShareLink 用（存到相册 / 发给别人都行）
    private var iconExportFile: URL? {
        guard let icon = profile.customIcon, let data = icon.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cloverchat-icon.png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    /// 提示词编辑器：多行、默认空白，占位文字说明"留空就是裸跑"
    private var promptEditor: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("AI 提示词")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("空")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.35))
                } else {
                    Text("\(prompt.count) 字")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.35))
                }
            }

            ZStack(alignment: .topLeading) {
                if prompt.isEmpty {
                    Text("例如：你是小树，说话简短自然，多用短句……\n留空则不发送任何提示词。")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.35))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 12)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $prompt)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
            .frame(height: 128)
            .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
            )
        }
    }

    /// 连发等待：发完消息先攒一会儿，再一起交给 AI
    private var delayRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("连发等待")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text(delaySeconds <= 0 ? "立即发给 AI" : "等 \(fmt(delaySeconds)) 秒再发")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(delaySeconds <= 0 ? .white.opacity(0.35) : Palette.sendMid.opacity(0.95))
            }

            HStack(spacing: 12) {
                Slider(value: $delaySeconds, in: 0...12, step: 0.5)
                    .tint(Color.white.opacity(0.85))
                Text("\(fmt(delaySeconds))s")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, alignment: .trailing)
                    .monospacedDigit()
            }

            Text("冷却期内再发一条会重新计时，最后整批一起给 AI —— 想连发几句就用它。")
                .font(.system(size: 11.5))
                .foregroundColor(.white.opacity(0.45))
                .lineSpacing(2)
        }
        .padding(12)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.8)
        )
    }

    private func fmt(_ value: Double) -> String {
        value == floor(value) ? String(Int(value)) : String(format: "%.1f", value)
    }

    private func save() {
        let trimmedBase = baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBase.isEmpty && !trimmedBase.lowercased().hasPrefix("http://") && !trimmedBase.lowercased().hasPrefix("https://") {
            // 地址不是 http/https：给一次警告触感，别让人以为已经保存了
            Haptics.fire(.warning)
            return
        }
        profile.name = String(name.trimmingCharacters(in: .whitespaces).prefix(12))
        profile.systemPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        profile.replyDelaySeconds = delaySeconds
        let trimmedApp = String(appName.trimmingCharacters(in: .whitespaces).prefix(10))
        if !trimmedApp.isEmpty { profile.appName = trimmedApp }
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
