import Foundation

@MainActor
final class CloneViewModel: ObservableObject {
    @Published var urlInput: String = ""
    @Published var isLoading = false
    @Published var cloneResult: CloneSiteResponse?
    @Published var errorMessage: String?
    @Published var showPreview = false

    private let apiClient = APIClient()

    func cloneSite(token: String) async {
        let trimmed = urlInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a URL to clone."
            return
        }
        guard URL(string: trimmed) != nil else {
            errorMessage = "Invalid URL. Please enter a valid https:// URL."
            return
        }

        isLoading = true
        cloneResult = nil
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result: CloneSiteResponse = try await apiClient.request(
                "/clone/site", method: "POST",
                body: CloneSitePayload(url: trimmed),
                token: token
            )
            cloneResult = result
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var previewURL: URL? {
        guard let result = cloneResult else { return nil }
        let base = APIConfig.baseURLString + result.previewUrl
        return URL(string: base)
    }
}
