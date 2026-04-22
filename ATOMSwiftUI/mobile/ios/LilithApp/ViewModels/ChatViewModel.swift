import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var threadUserID: String = ""
    @Published var messageText: String = ""
    @Published var messages: [Message] = []
    @Published var error: String?

    private let service = MessagingService()

    func loadThread() async {
        guard !threadUserID.isEmpty else { return }
        do {
            messages = try await service.fetchThread(with: threadUserID)
        } catch {
            error = String(describing: error)
        }
    }

    func send() async {
        guard !threadUserID.isEmpty, !messageText.isEmpty else { return }
        do {
            try await service.sendMessage(receiverID: threadUserID, content: messageText)
            messageText = ""
            await loadThread()
        } catch {
            error = String(describing: error)
        }
    }
}

