import Foundation

struct ProjectFileItem: Codable, Identifiable {
    let name: String
    let path: String?
    let content: String
    let language: String

    var id: String { path ?? name }
}

struct ProjectItem: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let files: [ProjectFileItem]
    let createdAt: String
    let updatedAt: String
}

struct CreateProjectPayload: Encodable {
    let name: String
    let description: String?
}
