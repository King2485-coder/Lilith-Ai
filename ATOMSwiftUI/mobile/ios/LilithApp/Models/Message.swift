import Foundation

struct Message: Codable, Identifiable {
    let id: String
    let sender_id: String
    let receiver_id: String
    let content: String
    let created_at: String
    let read_at: String?
}

struct ThreadResponse: Codable {
    let items: [Message]
}

