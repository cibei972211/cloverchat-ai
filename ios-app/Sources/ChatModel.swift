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
        guard !trimmed.isEmpty else { return }
        let cleanSubject = subject.trimmingCharacters(in: .whitespaces)
        messages.append(ChatMessage(role: .user, text: trimmed, subject: cleanSubject, time: Date()))
        persist()
        // v24：不再因为"正在回复"就把新消息吞掉。任何一次发送都会重置冷却计时，
        // 让用户能连着发几条，最后一起交给 AI。
        scheduleReply()
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
    }

    private func reset() {
        resetKeepingContext()
        messages = []
        persist()
    }

    /// 冷却 + 请求：每发一条消息调用一次，会取消上一次的计时/请求并重新计时。
    /// 所以"连发三条"的效果是：计时一直重置，等用户停手满了 N 秒，AI 才看到这三条。
    private func scheduleReply() {
        streamTask?.cancel()
        streamTask = nil

        // 打断旧回复：没说完的半句不留（说明用户抢话了），清掉流式态
        waitingReply = false
        streaming = false

        let name = profile.name
        let config = profile.apiConfig
        let systemPrompt = profile.systemPrompt
        let delay = max(0, profile.replyDelaySeconds)
        // 历史在调度时取快照；期间再来新消息会重新调度，所以快照始终跟得上
        let history = messages.suffix(20).map {
            ChatTurn(role: $0.role.rawValue, content: $0.text)
        }
        let userText = messages.last(where: { $0.role == .user })?.text ?? ""

        streamTask = Task { @MainActor [weak self] in
            guard let self else { return }
            self.streaming = true

            // 1) 冷却期：这段时间屏幕上不显示三点（消息已经落好了），用户还能继续发
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                if Task.isCancelled {
                    self.streaming = false
                    return
                }
            }

            // 2) 冷却结束，这时才让 AI 真正看到这一批消息
            self.waitingReply = true
            try? await Task.sleep(nanoseconds: 300_000_000)
            if Task.isCancelled {
                self.waitingReply = false
                self.streaming = false
                return
            }

            if config.isConfigured {
                do {
                    let full = try await APIClient().complete(config: config,
                                                              systemPrompt: systemPrompt,
                                                              history: history)
                    if Task.isCancelled { return }
                    self.deliver(full)
                } catch {
                    if Task.isCancelled { return }
                    let reply = PersonaEngine.reply(for: userText, subject: "", name: name)
                    self.deliver(reply)
                }
            } else {
                let reply = PersonaEngine.reply(for: userText, subject: "", name: name)
                try? await Task.sleep(nanoseconds: 420_000_000)
                if Task.isCancelled { return }
                self.deliver(reply)
            }

            if !Task.isCancelled {
                self.streaming = false
            }
        }
    }

    /// 一次性落成气泡（v26 取消逐字输出）：
    /// 消息进列表 + 三点消失，必须在同一个主线程 tick 内完成，
    /// 这样 SwiftUI 只合成一帧，不会出现"气泡没了、消息还没到"的空档。
    private func deliver(_ reply: String) {
        let text = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            waitingReply = false
            return
        }
        messages.append(ChatMessage(role: .assistant, text: text, time: Date()))
        persist()
        waitingReply = false
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
