import Foundation

enum APIConfig {
    /// Backend base URL. Override order: UserDefaults key "BackendURLOverride" -> Info.plist BACKEND_URL -> localhost
    static var baseURLString: String {
        if let override = UserDefaults.standard.string(forKey: "BackendURLOverride"),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return sanitize(url: override)
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
    /// LIVE BACKENDS ONLY — stubs disabled permanently.
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
        guard !APIConfig.baseURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let url = URL(string: APIConfig.baseURLString + path) else {
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
        guard let url = URL(string: APIConfig.baseURLString + APIConfig.apiPrefix + path) else {
            throw APIError.invalidURL
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        for (name, value) in fields {
            body.append("--\(boundary)\\r\\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\\r\\n\\r\\n".data(using: .utf8)!)
            body.append("\(value)\\r\\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)\\r\\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\\r\\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\\r\\n\\r\\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\\r\\n".data(using: .utf8)!)
        body.append("--\(boundary)--\\r\\n".data(using: .utf8)!)

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
