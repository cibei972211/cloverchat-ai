import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: Role
    var text: String
    var subject: String = ""
    var time = Date()

    enum Role: String, Codable {
        case user, assistant
    }
}

// MARK: - 一段完整对话（对话列表页用）

struct Conversation: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var messages: [ChatMessage]
    var updatedAt = Date()

    /// 最后一条消息（列表里做预览）
    var preview: String {
        guard let last = messages.last else { return "空的对话" }
        let prefix = last.role == .user ? "你：" : ""
        return prefix + last.text.replacingOccurrences(of: "\n", with: " ")
    }

    /// 用于搜索的全部文本
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return true }
        if title.lowercased().contains(q) { return true }
        return messages.contains { $0.text.lowercased().contains(q) || $0.subject.lowercased().contains(q) }
    }
}

@MainActor
final class ChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var streaming = false
    @Published var waitingReply = false
    @Published var liveText = ""
    @Published var liveActive = false

    /// 已经归档的历史对话（按更新时间倒序）
    @Published var conversations: [Conversation] = []

    private let profile: ProfileModel
    private var streamTask: Task<Void, Never>?
    private let fileURL: URL
    private let storeURL: URL

    init(profile: ProfileModel) {
        self.profile = profile
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("chat.json")
        storeURL = docs.appendingPathComponent("conversations.json")

        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = Array(saved.suffix(120))
        }
        if let data = try? Data(contentsOf: storeURL),
           let saved = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = saved.sorted { $0.updatedAt > $1.updatedAt }
        }
    }

    func send(text: String, subject: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !streaming else { return }
        let cleanSubject = subject.trimmingCharacters(in: .whitespaces)
        messages.append(ChatMessage(role: .user, text: trimmed, subject: cleanSubject, time: Date()))
        persist()
        startReply(userText: trimmed)
    }

    /// 开新对话：把当前这一段先归档，再清空
    func newChat() {
        archiveCurrent()
        reset()
    }

    /// 清空当前对话（不进历史）
    func clearChat() {
        reset()
    }

    /// 当前正在进行的这一段（有消息时才有），给对话列表页当作"当前"那一行
    var currentSummary: Conversation? {
        guard !messages.isEmpty else { return nil }
        return Conversation(
            id: messages[0].id,
            title: Self.title(for: messages),
            messages: messages,
            updatedAt: messages.last?.time ?? Date()
        )
    }

    /// 打开一段历史对话：先把当前归档，再把目标装进 messages
    func open(_ conversation: Conversation) {
        archiveCurrent()
        conversations.removeAll { $0.id == conversation.id }
        persistConversations()
        resetKeepingContext()
        messages = Array(conversation.messages.suffix(120))
        persist()
    }

    func delete(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        persistConversations()
    }

    /// 标题：优先用主题，其次用第一句用户消息
    static func title(for messages: [ChatMessage]) -> String {
        if let subject = messages.first(where: {
            !$0.subject.trimmingCharacters(in: .whitespaces).isEmpty
        })?.subject {
            return subject
        }
        if let first = messages.first(where: { $0.role == .user }) {
            let line = first.text
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty { return String(line.prefix(18)) }
        }
        return "新的对话"
    }

    // MARK: - 内部

    private func archiveCurrent() {
        guard !messages.isEmpty else { return }
        let conversation = Conversation(
            title: Self.title(for: messages),
            messages: messages,
            updatedAt: messages.last?.time ?? Date()
        )
        conversations.insert(conversation, at: 0)
        if conversations.count > 60 {
            conversations = Array(conversations.prefix(60))
        }
        persistConversations()
    }

    /// 停掉正在跑的回复，但不动归档数据
    private func resetKeepingContext() {
        streamTask?.cancel()
        streamTask = nil
        streaming = false
        waitingReply = false
        liveActive = false
        liveText = ""
    }

    private func reset() {
        resetKeepingContext()
        messages = []
        persist()
    }

    private func startReply(userText: String) {
        streamTask?.cancel()
        streaming = true
        waitingReply = true
        liveActive = false
        liveText = ""

        let name = profile.name
        let config = profile.apiConfig
        let history = messages.suffix(20).map {
            ChatTurn(role: $0.role.rawValue, content: $0.text)
        }

        streamTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 480_000_000)
            if Task.isCancelled { return }

            if config.isConfigured {
                do {
                    try await APIClient().stream(config: config,
                                                 systemPrompt: profile.systemPrompt,
                                                 name: name,
                                                 history: history) { full in
                        Task { @MainActor [weak self] in
                            // 第一个 delta 到达时，把"等待"和"逐字"在同一帧里交接完：
                            // waitingReply 与 liveActive 同时切换，气泡不会先消失再出现。
                            self?.liveActive = true
                            self?.liveText = full
                            self?.waitingReply = false
                        }
                    }
                    self.finishLive()
                } catch {
                    if Task.isCancelled { return }
                    let reply = PersonaEngine.reply(for: userText, subject: "", name: name)
                    await self.typeOut(reply)
                }
            } else {
                let reply = PersonaEngine.reply(for: userText, subject: "", name: name)
                try? await Task.sleep(nanoseconds: 420_000_000)
                if Task.isCancelled { return }
                await self.typeOut(reply)
            }

            if !Task.isCancelled {
                self.streaming = false
            }
        }
    }

    private func typeOut(_ reply: String) async {
        // 和真实接口一致：进入逐字阶段时才同时把 waitingReply 交出去
        waitingReply = false
        liveActive = true
        let chars = Array(reply)
        var index = 0
        let step = chars.count > 90 ? 2 : 1
        while index < chars.count {
            if Task.isCancelled {
                liveActive = false
                liveText = ""
                return
            }
            index = min(chars.count, index + step)
            liveText = String(chars[0..<index])
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        finishLive()
    }

    private func finishLive() {
        let text = liveText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            liveActive = false
            liveText = ""
            return
        }
        // 顺序很关键：先把完整消息落进 messages，再清流式气泡。
        // 两步都在同一次主线程 tick 里完成，SwiftUI 只合成一帧 ——
        // 反过来写会有一帧"气泡没了、消息还没到"，画面就跳一下。
        messages.append(ChatMessage(role: .assistant, text: text, time: Date()))
        persist()
        liveActive = false
        liveText = ""
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Array(messages.suffix(120))) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func persistConversations() {
        conversations.sort { $0.updatedAt > $1.updatedAt }
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }
}
