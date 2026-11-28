import Foundation

struct ChatTurn {
    let role: String
    let content: String
}

final class APIClient {
    /// 一次性拿到完整回复（v26 去掉流式）。
    ///
    /// 请求仍然用 `stream: true` 发出 —— 这条链路在各类中转/代理上都验证过，
    /// 兼容性最好；只是我们不再把每个 delta 抛给 UI，而是在这里攒完再一次性返回。
    /// 这样界面上就不存在「逐字重排 → 玻璃重绘 → 整屏闪」这一整类问题。
    ///
    /// - systemPrompt: 用户自己写的提示词。填空则**完全不发送 system 消息**。
    func complete(config: APIConfig,
                  systemPrompt: String,
                  history: [ChatTurn]) async throws -> String {
        var base = config.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/chat/completions") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = config.apiKey.trimmingCharacters(in: .whitespaces)
        if !key.isEmpty {
            request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        }

        // 用户提示词原样发送。留空就不发 system 消息（不再内置任何人格设定）。
        let trimmedPrompt = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        var messages: [[String: Any]] = []
        if !trimmedPrompt.isEmpty {
            messages.append(["role": "system", "content": trimmedPrompt])
        }
        messages.append(contentsOf: history.map {
            ["role": $0.role, "content": $0.content]
        })

        let body: [String: Any] = [
            "model": config.model,
            "stream": true,
            "temperature": 0.85,
            "messages": messages,
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        var full = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = object["choices"] as? [[String: Any]] else { continue }

            // 兼容流式 delta
            if let delta = choices.first?["delta"] as? [String: Any],
               let piece = delta["content"] as? String, !piece.isEmpty {
                full += piece
                continue
            }
            // 兼容某些中转在 stream 模式下直接吐整段 message
            if let message = choices.first?["message"] as? [String: Any],
               let piece = message["content"] as? String, !piece.isEmpty {
                full = piece
            }
        }

        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw URLError(.cannotParseResponse)
        }
        return trimmed
    }
}
