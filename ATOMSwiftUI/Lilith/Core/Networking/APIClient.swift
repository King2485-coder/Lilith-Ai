import Foundation

enum APIConfig {
    /// Backend base URL. Override order: BackendURLOverride -> serverURL -> Info.plist BACKEND_URL -> localhost
    static var baseURLString: String {
        if let override = UserDefaults.standard.string(forKey: "BackendURLOverride"),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sanitize(url: override)
        }
        if let legacy = UserDefaults.standard.string(forKey: "serverURL"),
           !legacy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sanitize(url: legacy)
        }
        if let url = Bundle.main.object(forInfoDictionaryKey: "BACKEND_URL") as? String,
           !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
           return sanitize(url: url)
       }
        return "http://127.0.0.1:8000"
    }

    static let apiPrefix = "/api"
    static let v1Prefix = "/api/v1"
    static let masterToken = "LILITH_MASTER_TOKEN"
    /// Set to true to allow offline stubbed responses (master/demo mode). Leave false for live-only behavior.
    static var useOfflineStubs = false

    private static func sanitize(url: String) -> String {
        var trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed
    }
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case http(statusCode: Int, message: String)
    case decoding(Error)
    case encoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend URL."
        case .invalidResponse:
            return "Invalid response from server."
        case let .http(statusCode, message):
            return message.isEmpty ? "Request failed with status \(statusCode)." : message
        case let .decoding(error):
            return "Failed to decode response: \(error.localizedDescription)"
        case let .encoding(error):
            return "Failed to encode request: \(error.localizedDescription)"
        }
    }
}

struct APIClient {
    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    func request<T: Decodable>(_ path: String, method: String = "GET", token: String? = nil) async throws -> T {
        try await execute(path: path, method: method, bodyData: nil, token: token)
    }

    func requestV1<T: Decodable>(_ path: String, method: String = "GET", token: String? = nil) async throws -> T {
        try await executeRaw(path: APIConfig.v1Prefix + path, method: method, bodyData: nil, token: token)
    }

    func request<Body: Encodable, T: Decodable>(_ path: String, method: String = "POST", body: Body?, token: String? = nil) async throws -> T {
        let bodyData: Data?

        if let body {
            do {
                bodyData = try encoder.encode(body)
            } catch {
                throw APIError.encoding(error)
            }
        } else {
            bodyData = nil
        }

        return try await execute(path: path, method: method, bodyData: bodyData, token: token)
    }

    func requestV1<Body: Encodable, T: Decodable>(_ path: String, method: String = "POST", body: Body?, token: String? = nil) async throws -> T {
        let bodyData: Data?

        if let body {
            do {
                bodyData = try encoder.encode(body)
            } catch {
                throw APIError.encoding(error)
            }
        } else {
            bodyData = nil
        }

        return try await executeRaw(path: APIConfig.v1Prefix + path, method: method, bodyData: bodyData, token: token)
    }

    private func execute<T: Decodable>(path: String, method: String, bodyData: Data?, token: String?) async throws -> T {
        try await executeRaw(path: APIConfig.apiPrefix + path, method: method, bodyData: bodyData, token: token)
    }

    private func executeRaw<T: Decodable>(path: String, method: String, bodyData: Data?, token: String?) async throws -> T {
        // Offline/owner bypass: return stubbed data when using the master token and stubs are enabled.
        if APIConfig.useOfflineStubs, token == APIConfig.masterToken, let stub = try? offlineStub(T.self, path: path, method: method) {
            return stub
        }

        guard !APIConfig.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: APIConfig.baseURLString + path) else {
                  // If URL is bad, still attempt stub for master/offline flows.
                  if APIConfig.useOfflineStubs, let stub = try? offlineStub(T.self, path: path, method: method) {
                      return stub
                  }
                  throw APIError.invalidURL
              }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let bodyData {
            request.httpBody = bodyData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
#if DEBUG
            if let bodyString = String(data: data, encoding: .utf8) {
                print("APIClient DEBUG \(method) \(url.absoluteString) [\(httpResponse.statusCode)]\\n\(bodyString)\\n")
            }
#endif

            guard (200 ... 299).contains(httpResponse.statusCode) else {
                let message = extractErrorMessage(from: data)
                throw APIError.http(statusCode: httpResponse.statusCode, message: message)
            }

            return try decoder.decode(T.self, from: data)
        } catch {
            // Fallback to stub when network or decode fails and stubs are enabled.
            if APIConfig.useOfflineStubs, let stub = try? offlineStub(T.self, path: path, method: method) {
                return stub
            }
            throw error
        }
    }

    func extractErrorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = object["detail"] as? String {
            return detail
        }

        return String(data: data, encoding: .utf8) ?? "Unknown server error"
    }
}

extension APIClient {
    func realtimeWebSocketURL(token: String) -> URL? {
        let httpURL = APIConfig.baseURLString
        guard var components = URLComponents(string: httpURL) else { return nil }
        components.path = APIConfig.v1Prefix + "/realtime/ws"
        components.queryItems = [URLQueryItem(name: "token", value: token)]
        switch components.scheme?.lowercased() {
        case "https":
            components.scheme = "wss"
        default:
            components.scheme = "ws"
        }
        return components.url
    }
}

private struct EmptyBody: Encodable {}

private extension APIClient {
    func offlineStub<T: Decodable>(_ type: T.Type, path: String, method: String) throws -> T {
        func decode(_ object: Any) throws -> T {
            let data = try JSONSerialization.data(withJSONObject: object, options: [])
            return try decoder.decode(T.self, from: data)
        }

        let nowISO = ISO8601DateFormatter().string(from: Date())

        switch T.self {
        case is SubscriptionResponse.Type:
            return try decode([
                "subscription": [
                    "plan": "master",
                    "status": "active",
                    "currentPeriodStart": nowISO,
                    "currentPeriodEnd": nowISO
                ],
                "credits": 9_999_999,
                "isSuperAdmin": true
            ])

        case is CreditsSummary.Type:
            return try decode([
                "credits": 9_999_999,
                "isSuperAdmin": true,
                "unlimited": true
            ])

        case is AdminStatsResponse.Type:
            return try decode([
                "users": ["total": 42, "active": 38, "premium": 20, "free": 22],
                "content": ["conversations": 320, "projects": 58, "videos": 24, "images": 140]
            ])

        case is [ConversationListItem].Type:
            return try decode([
                ["id": UUID().uuidString, "title": "Welcome to Lilith", "messages": 3, "updatedAt": nowISO]
            ])

        case is ConversationDetail.Type:
            return try decode([
                "id": UUID().uuidString,
                "title": "Welcome",
                "messages": [
                    ["role": "assistant", "content": "How can I help today?"],
                    ["role": "user", "content": "Show me what you can do."]
                ]
            ])

        case is BrowserSearchResponse.Type:
            return try decode([
                "success": true,
                "engine": "Lilith",
                "query": "stub search",
                "results": [
                    ["title": "Stub result 1", "url": "https://example.com/1", "snippet": "Example snippet 1"],
                    ["title": "Stub result 2", "url": "https://example.com/2", "snippet": "Example snippet 2"]
                ]
            ])

        case is ChatResponsePayload.Type:
            return try decode([
                "response": "Here’s a quick answer from the local master mode. Ask me anything!",
                "conversationId": UUID().uuidString,
                "messageId": UUID().uuidString
            ])

        case is [ProjectItem].Type:
            return try decode([stubProject(nowISO)])

        case is ProjectItem.Type:
            return try decode(stubProject(nowISO))

        case is CodeExecuteResponse.Type:
            return try decode(["success": true, "output": "Hello from Lilith master mode 👋"])

        case is AutoFixResponse.Type:
            return try decode(["success": true, "fixedCode": "// fixed code", "explanation": "Auto-fixed locally."])

        case is AutoFixLoopResponse.Type:
            return try decode([
                "success": true,
                "finalCode": "// final fixed code",
                "output": "All tests passed.",
                "totalAttempts": 1
            ])

        case is CodeReviewResponse.Type:
            return try decode([
                "summary": "Overall codebase is healthy. Apply a few accessibility and performance tweaks.",
                "suggestions": [
                    ["title": "Trim keyboard overlap", "detail": "Use safeAreaInset for composers and hide overlays while the keyboard is visible to keep inputs clear.", "severity": "medium"],
                    ["title": "Prefer structured logging", "detail": "Wrap console prints with a lightweight logger that can be silenced in production builds.", "severity": "low"],
                    ["title": "Optimize image decoding", "detail": "Defer heavy image decoding to a background queue before display to avoid jank on low-end devices.", "severity": "medium"]
                ]
            ])

        case is VideoGenerationResponse.Type:
            return try decode([
                "videoId": UUID().uuidString,
                "status": "ready",
                "videoUrl": "https://example.com/video.mp4"
            ])

        case is VideoStatusResponse.Type:
            return try decode([
                "videoId": UUID().uuidString,
                "status": "completed",
                "videoUrl": "https://example.com/video.mp4"
            ])

        case is ImageGenerationResponse.Type:
            let tinyTransparentPng = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="
            return try decode([
                "imageId": UUID().uuidString,
                "imageData": tinyTransparentPng,
                "textResponse": "Image generated (offline stub)."
            ])

        case is CloneSiteResponse.Type:
            return try decode([
                "id": UUID().uuidString,
                "url": "https://example.com",
                "code": "<html><body><h1>Cloned offline stub</h1></body></html>",
                "previewUrl": "https://example.com/preview"
            ])

        case is CheckoutResponse.Type:
            return try decode(["checkoutUrl": "https://example.com/checkout"])

        default:
            // If the consumer expects an empty decodable, try decoding from an empty dictionary.
            if let empty = try? decode([String: String]()) {
                return empty
            }
            throw APIError.invalidResponse
        }
    }

    func stubProject(_ nowISO: String) -> [String: Any] {
        [
            "id": UUID().uuidString,
            "name": "Sample Project",
            "description": "Offline master sample project.",
            "files": [
                [
                    "name": "README.md",
                    "path": "README.md",
                    "content": "# Hello from Lilith master mode\\nYou are offline but fully unlocked.",
                    "language": "markdown"
                ],
                [
                    "name": "main.py",
                    "path": "main.py",
                    "content": "print('Hello Lilith')",
                    "language": "python"
                ]
            ],
            "createdAt": nowISO,
            "updatedAt": nowISO
        ]
    }
}

extension APIClient {
    /// Multipart/form-data upload used for video-from-media.
    func uploadMultipart<T: Decodable>(
        _ path: String,
        fields: [String: String],
        fileField: String,
        fileData: Data,
        mimeType: String,
        fileName: String,
        token: String?
    ) async throws -> T {
        if token == APIConfig.masterToken, let stub = try? offlineStub(T.self, path: path, method: "POST") {
            return stub
        }

        guard let url = URL(string: APIConfig.baseURLString + APIConfig.apiPrefix + path) else {
            throw APIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        for (name, value) in fields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            let message = extractErrorMessage(from: data)
            throw APIError.http(statusCode: httpResponse.statusCode, message: message)
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
