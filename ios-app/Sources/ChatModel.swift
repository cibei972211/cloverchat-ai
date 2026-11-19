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

@MainActor
final class ChatModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var streaming = false
    @Published var waitingReply = false
    @Published var liveText = ""
    @Published var liveActive = false

    private let profile: ProfileModel
    private var streamTask: Task<Void, Never>?
    private let fileURL: URL

    init(profile: ProfileModel) {
        self.profile = profile
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = docs.appendingPathComponent("chat.json")
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            messages = Array(saved.suffix(120))
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

    func newChat() { reset() }
    func clearChat() { reset() }

    private func reset() {
        streamTask?.cancel()
        streamTask = nil
        streaming = false
        waitingReply = false
        liveActive = false
        liveText = ""
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
            self.waitingReply = false

            if config.isConfigured {
                do {
                    try await APIClient().stream(config: config, name: name, history: history) { full in
                        Task { @MainActor [weak self] in
                            self?.liveActive = true
                            self?.liveText = full
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
        liveActive = false
        liveText = ""
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(role: .assistant, text: text, time: Date()))
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(Array(messages.suffix(120))) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
