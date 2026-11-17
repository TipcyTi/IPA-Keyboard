import Foundation

enum OpenAIError: LocalizedError {
    case invalidURL
    case noResponse
    case http(Int, String)
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "地址无效"
        case .noResponse:
            return "无响应"
        case .http(let code, let message):
            let base: String
            switch code {
            case 401, 403:
                base = "认证失败 (\(code))"
            case 404:
                base = "接口不存在 (\(code))"
            case 429:
                base = "请求过于频繁 (\(code))"
            default:
                base = "请求失败 (\(code))"
            }
            return message.isEmpty ? base : "\(base) · \(message)"
        case .empty:
            return "返回为空"
        }
    }
}

enum OpenAIService {
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 900
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = ["User-Agent": "AIChat/1.0 (iOS)"]
        return URLSession(configuration: configuration)
    }()

    static func chatURL(for base: String) -> URL? {
        let value = normalized(base)
        guard !value.isEmpty else { return nil }
        if value.lowercased().hasSuffix("/chat/completions") { return URL(string: value) }
        return URL(string: value + "/chat/completions")
    }

    static func modelsURL(for base: String) -> URL? {
        var value = normalized(base)
        if value.lowercased().hasSuffix("/chat/completions") {
            value = String(value.dropLast("/chat/completions".count))
        }
        guard !value.isEmpty else { return nil }
        return URL(string: value + "/models")
    }

    private static func normalized(_ raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }
        let lower = value.lowercased()
        if !lower.hasPrefix("http://") && !lower.hasPrefix("https://") {
            value = "https://" + value
        }
        while value.hasSuffix("/") { value.removeLast() }
        return value
    }

    static func stream(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [APIMessage]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = chatURL(for: baseURL) else { throw OpenAIError.invalidURL }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

                    let body: [String: Any] = [
                        "model": model,
                        "messages": messages.map { ["role": $0.role, "content": $0.content] },
                        "stream": true
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw OpenAIError.noResponse }

                    guard (200..<300).contains(http.statusCode) else {
                        var raw = ""
                        for try await line in bytes.lines {
                            raw += line
                            if raw.count > 6000 { break }
                        }
                        throw OpenAIError.http(http.statusCode, errorMessage(from: raw))
                    }

                    var emitted = false
                    var raw = ""

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        if trimmed.hasPrefix("data:") {
                            let payload = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                            if payload == "[DONE]" { break }
                            if let text = deltaText(payload), !text.isEmpty {
                                emitted = true
                                continuation.yield(text)
                            }
                        } else if !trimmed.isEmpty {
                            if raw.count < 2_000_000 { raw += line }
                        }
                    }

                    if Task.isCancelled {
                        continuation.finish()
                        return
                    }

                    if !emitted {
                        if !raw.isEmpty, let text = messageText(from: raw), !text.isEmpty {
                            continuation.yield(text)
                        } else {
                            throw OpenAIError.empty
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func models(baseURL: String, apiKey: String) async throws -> [String] {
        guard let url = modelsURL(for: baseURL) else { throw OpenAIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw OpenAIError.noResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenAIError.http(http.statusCode, errorMessage(from: String(data: data, encoding: .utf8) ?? ""))
        }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let list = object["data"] as? [[String: Any]] else {
            throw OpenAIError.empty
        }
        let ids = list.compactMap { $0["id"] as? String }
        return Array(Set(ids)).sorted()
    }

    static func describe(_ error: Error) -> String {
        if let error = error as? OpenAIError, let description = error.errorDescription {
            return description
        }
        if let error = error as? URLError {
            switch error.code {
            case .notConnectedToInternet:
                return "网络未连接"
            case .timedOut:
                return "请求超时"
            case .cannotFindHost:
                return "无法解析域名"
            case .cannotConnectToHost:
                return "无法连接服务器"
            case .secureConnectionFailed, .serverCertificateUntrusted:
                return "安全连接失败"
            default:
                return "网络错误 (\(error.code.rawValue))"
            }
        }
        return error.localizedDescription
    }

    private static func deltaText(_ json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let first = choices.first,
              let delta = first["delta"] as? [String: Any],
              let content = delta["content"] as? String else {
            return nil
        }
        return content
    }

    private static func messageText(from raw: String) -> String? {
        guard let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = object["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            return nil
        }
        return content
    }

    private static func errorMessage(from raw: String) -> String {
        if let data = raw.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return shorten(message)
        }
        return shorten(raw)
    }

    private static func shorten(_ text: String) -> String {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.count > 160 ? String(clean.prefix(160)) + "…" : clean
    }
}
