import Foundation

struct MessageSendPayload: Encodable {
    let receiver_id: String
    let content: String
}

final class MessagingService {
    private let api = APIClient.shared

    func sendMessage(receiverID: String, content: String) async throws {
        let _: [String: String] = try await api.post(
            "/api/v1/messages/send",
            body: MessageSendPayload(receiver_id: receiverID, content: content)
        )
    }

    func fetchThread(with userID: String) async throws -> [Message] {
        let response: ThreadResponse = try await api.get("/api/v1/messages/thread/\(userID)")
        return response.items
    }
}

