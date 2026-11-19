import Foundation

struct ChatTurn {
    let role: String
    let content: String
}

final class APIClient {
    func stream(config: APIConfig,
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

        let system = "你是「\(name)」，用户自定义的 AI 聊天伙伴。用简体中文回复，语气柔和自然，"
            + "像熟悉的朋友。回复简洁（通常不超过三句），多回应情绪和具体感受，少说教，不说空话。"
        let systemMessage: [String: Any] = ["role": "system", "content": system]
        let historyMessages: [[String: Any]] = history.map {
            ["role": $0.role, "content": $0.content]
        }
        let body: [String: Any] = [
            "model": config.model,
            "stream": true,
            "temperature": 0.85,
            "messages": [systemMessage] + historyMessages,
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
