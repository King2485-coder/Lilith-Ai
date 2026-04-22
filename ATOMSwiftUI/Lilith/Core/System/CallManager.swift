import Foundation
import CallKit

final class CallManager: NSObject, CXProviderDelegate {

    static let shared = CallManager()

    private let provider: CXProvider
    private let callController = CXCallController()

    private override init() {
        let config = CXProviderConfiguration()
        config.supportsVideo = true

        provider = CXProvider(configuration: config)

        super.init()
        provider.setDelegate(self, queue: nil)
    }

    var currentCallID: UUID?

    func receiveIncomingCall(from user: String) {

        let uuid = UUID()
        currentCallID = uuid

        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: user)
        update.hasVideo = true

        Task {
            do {
                try await provider.reportNewIncomingCall(with: uuid, update: update)
            } catch {
                print("Failed to report incoming call: \(error)")
            }
        }
    }

    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        WebRTCManager.shared.startConnection()
        action.fulfill()
    }

    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        WebRTCManager.shared.endConnection()
        action.fulfill()
    }

    func providerDidReset(_ provider: CXProvider) {
        WebRTCManager.shared.endConnection()
    }
}
