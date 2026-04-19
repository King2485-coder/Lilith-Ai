import Foundation

// MARK: - Result Types for Center Manifestation

enum ResultType {
    case image
    case video
    case text
    case media
}

enum ResultStatus {
    case pending
    case complete
}

struct ResultPayload: Identifiable, Equatable {
    let id = UUID()
    let type: ResultType
    let content: String
    let url: URL?
    let imageData: String?
    let status: ResultStatus
}

// MARK: - Chat View Model

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessageItem] = []
    @Published var draft = ""
    @Published var conversationId: String?
    @Published var isSending = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    @Published var activeResult: ResultPayload?
    var onAssistantSpoken: ((String) -> Void)?

    private let apiClient = APIClient()

    func sendMessage(token: String, agent: AgentKind, mode: AgentMode, ultraThinking: Bool) async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let outbound = ChatMessageItem(role: .user, content: trimmed, createdAt: .now, toolUsed: nil, preview: nil, approvalId: nil, plan: nil)
        messages.append(outbound)
        draft = ""
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        // Detect high-value output commands
        let isImageCommand = isImageGenerationRequest(trimmed)
        let isMediaCommand = isMediaRequest(trimmed)

        // Set pending result for high-value outputs
        if isImageCommand || isMediaCommand {
            activeResult = ResultPayload(
                type: isImageCommand ? .image : .media,
                content: "Creating...",
                url: nil,
                imageData: nil,
                status: .pending
            )
        }

        do {
            let response: ChatResponsePayload = try await apiClient.request(
                "/chat",
                method: "POST",
                body: ChatRequestPayload(
                    message: trimmed,
                    conversationId: conversationId,
                    context: nil,
                    projectId: nil,
                    autoFix: false,
                    agent: agent.rawValue,
                    mode: mode.rawValue,
                    ultraThinking: ultraThinking
                ),
                token: token
            )
            if let cid = response.conversationId {
                conversationId = cid
            }
            try? await Task.sleep(for: .milliseconds(180))

            // Route high-value outputs to center manifestation
            if isImageCommand || isMediaCommand {
                if let imageURL = extractImageURL(from: response.assistantText) {
                    activeResult = ResultPayload(
                        type: .image,
                        content: "",
                        url: imageURL,
                        imageData: nil,
                        status: .complete
                    )
                } else if let base64 = extractImageData(from: response.assistantText) {
                    activeResult = ResultPayload(
                        type: .image,
                        content: "",
                        url: nil,
                        imageData: base64,
                        status: .complete
                    )
                } else {
                    // Backend returned text instead of an image — show in chat
                    activeResult = nil
                    messages.append(
                        ChatMessageItem(
                            role: .assistant,
                            content: response.assistantText,
                            createdAt: .now,
                            toolUsed: response.toolUsed,
                            preview: response.preview ?? response.approvalRequest?.preview,
                            approvalId: response.approvalRequest?.approvalId,
                            plan: response.plan
                        )
                    )
                }
            } else {
                // Normal text response — left channel (communication/history)
                messages.append(
                    ChatMessageItem(
                        role: .assistant,
                        content: response.assistantText,
                        createdAt: .now,
                        toolUsed: response.toolUsed,
                        preview: response.preview ?? response.approvalRequest?.preview,
                        approvalId: response.approvalRequest?.approvalId,
                        plan: response.plan
                    )
                )
            }
            onAssistantSpoken?(response.assistantText)
        } catch {
            errorMessage = error.localizedDescription
            activeResult = nil
            messages.append(
                ChatMessageItem(
                    role: .assistant,
                    content: "Request failed: \(error.localizedDescription)",
                    createdAt: .now,
                    toolUsed: nil,
                    preview: nil,
                    approvalId: nil,
                    plan: nil
                )
            )
        }
    }

    func searchWeb(token: String, query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let response: BrowserSearchResponse = try await apiClient.request(
                "/browser/search",
                method: "POST",
                body: BrowserSearchRequest(query: trimmed),
                token: token
            )
            let bullets = response.results.prefix(3).map { "• \($0.title) — \($0.url)\n  \($0.snippet)" }.joined(separator: "\n")
            let summary = """
Lilith searched "\(response.query)":
\(bullets.isEmpty ? "No results." : bullets)
"""
            messages.append(
                ChatMessageItem(
                    role: .assistant,
                    content: summary,
                    createdAt: .now,
                    toolUsed: "Search",
                    preview: nil,
                    approvalId: nil,
                    plan: nil
                )
            )
        } catch {
            errorMessage = error.localizedDescription
            messages.append(
                ChatMessageItem(
                    role: .assistant,
                    content: "Lilith search failed: \(error.localizedDescription)",
                    createdAt: .now,
                    toolUsed: nil,
                    preview: nil,
                    approvalId: nil,
                    plan: nil
                )
            )
        }
    }

    func generateImage(prompt: String, token: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        activeResult = ResultPayload(
            type: .image,
            content: "Creating...",
            url: nil,
            imageData: nil,
            status: .pending
        )
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let response: ImageGenerationResponse = try await apiClient.request(
                "/image/generate",
                method: "POST",
                body: ImageGenerationPayload(prompt: trimmed),
                token: token
            )
            activeResult = ResultPayload(
                type: .image,
                content: response.textResponse ?? "",
                url: nil,
                imageData: response.imageData,
                status: .complete
            )
        } catch {
            errorMessage = error.localizedDescription
            activeResult = nil
        }
    }

    func generateVideo(prompt: String, duration: Int, token: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        activeResult = ResultPayload(
            type: .video,
            content: "Creating video...",
            url: nil,
            imageData: nil,
            status: .pending
        )
        isSending = true
        errorMessage = nil
        defer { isSending = false }

        do {
            let response: VideoGenerationResponse = try await apiClient.request(
                "/video/generate",
                method: "POST",
                body: VideoGenerationPayload(prompt: trimmed, size: "1280x720", duration: duration),
                token: token
            )
            if let videoUrlString = response.videoUrl, let url = URL(string: videoUrlString) {
                activeResult = ResultPayload(
                    type: .video,
                    content: "",
                    url: url,
                    imageData: nil,
                    status: .complete
                )
            } else {
                activeResult = ResultPayload(
                    type: .text,
                    content: "Video status: \(response.status)\nID: \(response.videoId)",
                    url: nil,
                    imageData: nil,
                    status: .complete
                )
            }
        } catch {
            errorMessage = error.localizedDescription
            activeResult = nil
        }
    }

    func startNewConversation() {
        messages = []
        conversationId = nil
        errorMessage = nil
        activeResult = nil
    }

    func loadConversation(id: String, token: String) async {
        do {
            let detail: ConversationDetail = try await apiClient.request(
                "/conversations/\(id)", token: token
            )
            conversationId = id
            messages = detail.messages.map { msg in
                ChatMessageItem(
                    role: msg.role == "user" ? .user : .assistant,
                    content: msg.content,
                    createdAt: .now,
                    toolUsed: nil,
                    preview: nil,
                    approvalId: nil,
                    plan: nil
                )
            }
            activeResult = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Intent Detection

    private func isImageGenerationRequest(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let imageKeywords = [
            "create an image", "generate an image", "make an image",
            "draw", "paint", "sketch", "illustrate",
            "image of", "picture of", "photo of",
            "render", "visualize", "design"
        ]
        return imageKeywords.contains { lowered.contains($0) }
    }

    private func isMediaRequest(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let mediaKeywords = [
            "video", "animation", "motion", "clip",
            "reel", "short", "film", "movie"
        ]
        return mediaKeywords.contains { lowered.contains($0) }
    }

    private func extractImageURL(from text: String) -> URL? {
        // Markdown image syntax: ![alt](url)
        let pattern = "!\\[(.*?)\\]\\((.*?)\\)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsString = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            if match.numberOfRanges > 2 {
                let urlRange = match.range(at: 2)
                let urlString = nsString.substring(with: urlRange)
                return URL(string: urlString)
            }
        }

        // Plain image URLs
        let urlPattern = "https?://[^\\s]+\\.(jpg|jpeg|png|gif|webp)"
        if let urlRegex = try? NSRegularExpression(pattern: urlPattern, options: .caseInsensitive) {
            let urlMatches = urlRegex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            if let firstMatch = urlMatches.first, firstMatch.range.location != NSNotFound {
                let urlString = nsString.substring(with: firstMatch.range)
                return URL(string: urlString)
            }
        }

        return nil
    }

    private func extractImageData(from text: String) -> String? {
        // Look for base64 data URIs or raw base64 blocks
        let dataURIPattern = "data:image/[^;]+;base64,([A-Za-z0-9+/=]+)"
        if let regex = try? NSRegularExpression(pattern: dataURIPattern) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            if let firstMatch = matches.first, firstMatch.range(at: 1).location != NSNotFound {
                return nsString.substring(with: firstMatch.range(at: 1))
            }
        }

        // Look for raw base64 strings that look like images (reasonable length)
        let rawBase64Pattern = "([A-Za-z0-9+/]{1000,}={0,2})"
        if let regex = try? NSRegularExpression(pattern: rawBase64Pattern) {
            let nsString = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsString.length))
            if let firstMatch = matches.first, firstMatch.range(at: 1).location != NSNotFound {
                return nsString.substring(with: firstMatch.range(at: 1))
            }
        }

        return nil
    }
}
