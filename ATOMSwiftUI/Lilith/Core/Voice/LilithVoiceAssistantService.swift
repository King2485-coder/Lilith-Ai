import Foundation

struct LilithVoiceReply {
    let assistantText: String
    let toolText: String
    let conversationId: String?

    var combinedText: String {
        if toolText.isEmpty {
            return assistantText
        }
        return "\(assistantText)\n\n\(toolText)"
    }
}

final class LilithVoiceAssistantService {
    private let apiClient = APIClient()

    func respond(to prompt: String, conversationId: String?) async -> LilithVoiceReply {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return LilithVoiceReply(
                assistantText: "I didn't catch that. Try asking Lilith again.",
                toolText: "",
                conversationId: conversationId
            )
        }

        let toolText = toolHint(for: trimmed)

        do {
            let response: ChatResponsePayload = try await apiClient.request(
                "/chat",
                method: "POST",
                body: ChatRequestPayload(
                    message: trimmed,
                    conversationId: conversationId,
                    context: "Voice assistant mode",
                    projectId: nil,
                    autoFix: false,
                    agent: AgentKind.nova.rawValue,
                    mode: AgentMode.mobile.rawValue,
                    ultraThinking: false
                ),
                token: nil
            )

            let assistant = response.assistantText.trimmingCharacters(in: .whitespacesAndNewlines)
            return LilithVoiceReply(
                assistantText: assistant.isEmpty ? "Lilith is ready for the next command." : assistant,
                toolText: toolText,
                conversationId: response.conversationId ?? conversationId
            )
        } catch {
            return fallbackReply(for: trimmed, toolText: toolText, conversationId: conversationId, error: error)
        }
    }

    private func fallbackReply(for prompt: String, toolText: String, conversationId: String?, error: Error?) -> LilithVoiceReply {
        let lead: String

        if let error {
            lead = "I couldn't reach the live Lilith backend, so I'm using local voice mode. \(error.localizedDescription)"
        } else {
            lead = "You're in local voice mode."
        }

        let assistant: String
        switch classify(prompt) {
        case .call:
            assistant = "I heard a call request. I can prepare that flow once communication actions are wired into this screen."
        case .video:
            assistant = "I heard a video request. I can route you toward Lilith's media tools from here."
        case .post:
            assistant = "I heard a post request. I can help draft the post and hand it off to the social layer."
        case .message:
            assistant = "I heard a message request. I can capture the recipient and draft the message next."
        case .unknown:
            assistant = "Ask for a message, call, video, post, or a general assistant task and Lilith will respond here."
        }

        return LilithVoiceReply(
            assistantText: "\(lead) \(assistant)",
            toolText: toolText,
            conversationId: conversationId
        )
    }

    private func toolHint(for prompt: String) -> String {
        switch classify(prompt) {
        case .call:
            return "Tool hint: prepare a secure call flow."
        case .video:
            return "Tool hint: open video creation tools."
        case .post:
            return "Tool hint: prepare a social post draft."
        case .message:
            return "Tool hint: prepare a secure message."
        case .unknown:
            return "Tool hint: general assistant task queued."
        }
    }

    private func classify(_ prompt: String) -> VoiceIntent {
        let text = prompt.lowercased()
        if text.contains("call") { return .call }
        if text.contains("video") { return .video }
        if text.contains("post") { return .post }
        if text.contains("text") || text.contains("message") { return .message }
        return .unknown
    }
}

private enum VoiceIntent {
    case message
    case video
    case call
    case post
    case unknown
}