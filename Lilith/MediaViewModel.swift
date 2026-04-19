import Foundation

struct VideoGenerationPayload: Encodable {
    let prompt: String
    let size: String
    let duration: Int
}

struct VideoGenerationResponse: Decodable {
    let videoId: String
    let status: String
    let videoUrl: String?
}

struct ImageGenerationPayload: Encodable {
    let prompt: String
}

struct ImageGenerationResponse: Decodable {
    let imageId: String
    let imageData: String
    let textResponse: String?
}

@MainActor
final class MediaViewModel: ObservableObject {
    @Published var videoPrompt = ""
    @Published var imagePrompt = ""
    @Published var selectedVideoDuration = 4
    @Published var generatedVideoStatus: String?
    @Published var generatedImageData: String?
    @Published var isGeneratingVideo = false
    @Published var isGeneratingImage = false
    @Published var errorMessage: String?

    private let apiClient = APIClient()

    func generateVideo(token: String) async {
        guard !videoPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Video prompt is required."
            return
        }

        isGeneratingVideo = true
        defer { isGeneratingVideo = false }

        do {
            let response: VideoGenerationResponse = try await apiClient.request(
                "/video/generate",
                method: "POST",
                body: VideoGenerationPayload(prompt: videoPrompt, size: "1280x720", duration: selectedVideoDuration),
                token: token
            )
            generatedVideoStatus = "Status: \(response.status)\nVideo ID: \(response.videoId)"
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func generateImage(token: String) async {
        guard !imagePrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Image prompt is required."
            return
        }

        isGeneratingImage = true
        defer { isGeneratingImage = false }

        do {
            let response: ImageGenerationResponse = try await apiClient.request(
                "/image/generate",
                method: "POST",
                body: ImageGenerationPayload(prompt: imagePrompt),
                token: token
            )
            generatedImageData = response.imageData
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
