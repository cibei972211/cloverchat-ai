import Foundation

struct ChatTurn {
    let role: String
    let content: String
}

final class APIClient {
    /// - systemPrompt: 用户自己写的提示词。填空则**完全不发送 system 消息**，
    ///   模型按接口默认行为回复，不再有内置人格。
    func stream(config: APIConfig,
                systemPrompt: String,
                name: String,
                history: [ChatTurn],
                onDelta: @escaping (String) -> Void) async throws {
        var base = config.baseUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        while base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: base + "/chat/completions") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
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
                  let choices = object["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let piece = delta["content"] as? String, !piece.isEmpty else { continue }
            full += piece
            onDelta(full)
        }

        guard !full.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw URLError(.cannotParseResponse)
        }
    }
}
