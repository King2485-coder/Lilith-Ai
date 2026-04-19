import Foundation
import UIKit

@MainActor
final class VideoViewModel: ObservableObject {
    enum VideoMode { case text, media }

    @Published var mode: VideoMode = .text
    @Published var prompt = ""
    @Published var selectedSize = "1280x720"
    @Published var selectedDuration = 4
    @Published var isGenerating = false
    @Published var videoStatus: String?
    @Published var videoId: String?
    @Published var videoURL: URL?
    @Published var errorMessage: String?

    // Media upload
    @Published var uploadedPhotoData: Data?
    @Published var uploadedMimeType: String = "image/jpeg"
    @Published var uploadedFileName: String = "upload.jpg"

    private let apiClient = APIClient()
    private var pollTask: Task<Void, Never>?

    let sizeOptions = ["1280x720", "1792x1024", "1024x1792", "1024x1024"]
    let durationOptions = [4, 8, 12]

    func generate(token: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a prompt."
            return
        }
        if mode == .media && uploadedPhotoData == nil {
            errorMessage = "Please select an image or video first."
            return
        }

        isGenerating = true
        videoStatus = "processing"
        videoURL = nil
        errorMessage = nil

        do {
            let response: VideoGenerationResponse

            if mode == .media, let data = uploadedPhotoData {
                response = try await apiClient.uploadMultipart(
                    "/video/from-media",
                    fields: [
                        "prompt": trimmed,
                        "size": selectedSize,
                        "duration": String(selectedDuration)
                    ],
                    fileField: "media",
                    fileData: data,
                    mimeType: uploadedMimeType,
                    fileName: uploadedFileName,
                    token: token
                )
            } else {
                response = try await apiClient.request(
                    "/video/generate", method: "POST",
                    body: VideoGenerationPayload(prompt: trimmed, size: selectedSize, duration: selectedDuration),
                    token: token
                )
            }

            videoId = response.videoId
            startPolling(videoId: response.videoId, token: token)
        } catch {
            errorMessage = error.localizedDescription
            isGenerating = false
            videoStatus = nil
        }
    }

    private func startPolling(videoId: String, token: String) {
        pollTask?.cancel()
        pollTask = Task {
            var attempts = 0
            while attempts < 120 {   // poll up to 10 minutes
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard !Task.isCancelled else { return }
                do {
                    let status: VideoStatusResponse = try await apiClient.request(
                        "/video/status/\(videoId)", token: token
                    )
                    videoStatus = status.status
                    if status.status == "completed" {
                        if let urlPath = status.videoUrl {
                            if urlPath.hasPrefix("http://") || urlPath.hasPrefix("https://") {
                                videoURL = URL(string: urlPath)
                            } else {
                                videoURL = URL(string: APIConfig.baseURLString + urlPath)
                            }
                        }
                        isGenerating = false
                        return
                    } else if status.status == "failed" {
                        errorMessage = "Video generation failed."
                        isGenerating = false
                        return
                    }
                } catch {
                    // ignore transient poll errors
                }
                attempts += 1
            }
            errorMessage = "Timed out waiting for video."
            isGenerating = false
        }
    }
}

struct VideoStatusResponse: Decodable {
    let videoId: String
    let status: String
    let videoUrl: String?
}
