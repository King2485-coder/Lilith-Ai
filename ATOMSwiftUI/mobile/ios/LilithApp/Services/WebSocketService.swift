import Foundation

final class WebSocketService: ObservableObject {
    private var task: URLSessionWebSocketTask?
    private var token: String = ""

    @Published var events: [[String: Any]] = []

    func connect(token: String) {
        self.token = token
        guard let url = URL(string: "\(APIClient.shared.baseURL)/api/v1/realtime/ws?token=\(token)") else { return }
        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        receive()
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    func send(event: String, payload: [String: Any]) {
        guard let task else { return }
        let frame: [String: Any] = ["event": event, "payload": payload]
        guard let data = try? JSONSerialization.data(withJSONObject: frame),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { _ in }
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message,
                   let data = text.data(using: .utf8),
                   let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    DispatchQueue.main.async { self.events.append(object) }
                }
                self.receive()
            case .failure:
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                    guard let self else { return }
                    self.connect(token: self.token)
                }
            }
        }
    }
}

