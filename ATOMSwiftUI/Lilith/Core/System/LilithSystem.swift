import SwiftUI
import Network

// =======================
// MARK: - MAIN SYSTEM
// =======================
// LilithSystem unifies server discovery (Bonjour + cloud fallback),
// auth token management, WebSocket connection, heartbeat, and
// reconnect logic into a single observable singleton.
//
// Note:
//  - APIConfig is defined in Core/Networking/APIClient.swift
//  - LilithUser  is defined in Features/Auth/AuthModels.swift
// =======================

@MainActor
final class LilithSystem: ObservableObject {

    static let shared = LilithSystem()

    // =======================
    // STATE
    // =======================

    @Published var serverURL: String = ""
    @Published var status: String = "Starting..."
    @Published var isConnected = false
    @Published var isAuthenticated = false
    @Published var messages: [String] = []
    @Published var presence: [String: String] = [:]

    private var socket: URLSessionWebSocketTask?
    private var browser: NWBrowser?
    private var heartbeatTimer: Timer?

    private var token: String?
    private var reconnectAttempts = 0

    // =======================
    // START SYSTEM
    // =======================

    func start() {
        Task {
            await connect()
        }
    }

    // =======================
    // FULL CONNECTION FLOW
    // =======================

    func connect() async {
        status = "Connecting..."

        // 1. Try cached server
        if let saved = UserDefaults.standard.string(forKey: "BackendURLOverride"),
           !saved.isEmpty, await test(saved) {
            serverURL = saved
            await finishConnection("Cached ⚡")
            return
        }

        // 2. Parallel: Bonjour + Cloud
        let productionURL = APIConfig.baseURLString
        async let local = discoverBonjour()
        async let cloudUp = test(productionURL)

        if let localURL = await local {
            serverURL = localURL
            await finishConnection("Local ⚡")
            return
        }

        if await cloudUp {
            serverURL = productionURL
            await finishConnection("Cloud ☁️")
            return
        }

        status = "No server ❌"
    }

    // =======================
    // FINALIZE CONNECTION
    // =======================

    func finishConnection(_ label: String) async {
        status = label
        UserDefaults.standard.set(serverURL, forKey: "BackendURLOverride")

        await authenticate()
        connectSocket()
        startHeartbeat()
    }

    // =======================
    // TEST SERVER
    // =======================

    func test(_ urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.timeoutInterval = 2

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    // =======================
    // BONJOUR DISCOVERY
    // =======================

    nonisolated func discoverBonjour() async -> String? {
        await withCheckedContinuation { cont in
            final class ResumeState: @unchecked Sendable {
                private let lock = NSLock()
                private var hasResumed = false

                func claim() -> Bool {
                    lock.lock()
                    defer { lock.unlock() }
                    guard !hasResumed else { return false }
                    hasResumed = true
                    return true
                }
            }

            let resumeState = ResumeState()
            let resolve: @Sendable (String?) -> Void = { value in
                guard resumeState.claim() else { return }
                cont.resume(returning: value)
            }

            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let browser = NWBrowser(
                for: .bonjour(type: "_http._tcp.", domain: "local."),
                using: params
            )

            browser.stateUpdateHandler = { state in
                if case .failed = state { resolve(nil) }
            }

            browser.browseResultsChangedHandler = { results, _ in
                for result in results {
                    if case let .service(name, _, _, _) = result.endpoint,
                       name.lowercased().contains("lilith") {

                        let connection = NWConnection(to: result.endpoint, using: .tcp)
                        connection.stateUpdateHandler = { connState in
                            if case .ready = connState,
                               let path = connection.currentPath,
                               let remote = path.remoteEndpoint,
                               case let .hostPort(host, port) = remote {
                                let ip = "\(host)"
                                    .replacingOccurrences(of: "%.*", with: "", options: .regularExpression)
                                resolve("http://\(ip):\(port)")
                                connection.cancel()
                            }
                            if case .failed = connState {
                                connection.cancel()
                            }
                        }
                        connection.start(queue: .global())
                        browser.cancel()
                        return
                    }
                }
            }

            browser.start(queue: .global())

            DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
                browser.cancel()
                resolve(nil)
            }
        }
    }

    // =======================
    // AUTHENTICATION
    // =======================

    func authenticate() async {
        // Try saved token first.
        if let saved = UserDefaults.standard.string(forKey: "lilith_token"),
           !saved.isEmpty {
            token = saved
            isAuthenticated = true
            return
        }

        guard let url = URL(string: "\(serverURL)/api/auth/login") else { return }

        let body: [String: Any] = [
            "email": "test@lilith.ai",
            "password": "123456",
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 5

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            if let t = json?["token"] as? String {
                token = t
                UserDefaults.standard.set(t, forKey: "lilith_token")
                isAuthenticated = true
            }
        } catch {
            // Auth optional — socket and voice work without a token.
        }
    }

    // =======================
    // WEBSOCKET
    // =======================

    func connectSocket() {
        guard let token = token else { return }

        let wsURLString = serverURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
            + "/ws/user1"

        guard let url = URL(string: wsURLString) else { return }

        var request = URLRequest(url: url)
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        socket?.cancel(with: .goingAway, reason: nil)
        socket = URLSession.shared.webSocketTask(with: request)
        socket?.resume()

        isConnected = true
        reconnectAttempts = 0
        listen()
    }

    func listen() {
        socket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .success(.string(let text)):
                    self.messages.append(text)
                    self.handleIncoming(text)

                case .failure:
                    self.handleDisconnect()
                    return

                default:
                    break
                }

                self.listen()
            }
        }
    }

    func handleIncoming(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "presence":
            if let user = json["user"] as? String,
               let status = json["status"] as? String {
                DispatchQueue.main.async {
                    self.presence[user] = status
                }
            }

        case "offer":
            WebRTCManager.shared.receiveOffer(json)

        case "answer":
            WebRTCManager.shared.receiveAnswer(json)

        case "ice":
            WebRTCManager.shared.receiveICE(json)

        case "call":
            let from = json["from"] as? String ?? "Unknown"
            CallManager.shared.receiveIncomingCall(from: from)

        default:
            break
        }
    }

    func handleDisconnect() {
        isConnected = false
        socket?.cancel()

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            await MainActor.run {
                self?.connectSocket()
            }
        }
    }

    func send(_ text: String) {
        socket?.send(.string(text)) { _ in }
    }

    func sendSignal(_ payload: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let text = String(data: data, encoding: .utf8) else { return }
        send(text)
    }

    // =======================
    // HEARTBEAT
    // =======================

    func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.send("{\"type\":\"heartbeat\"}")
            }
        }
    }

    func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
    }

    func connectWithPriority() async {
        async let local = discoverBonjour()
        async let cloud = test(APIConfig.baseURLString)

        try? await Task.sleep(nanoseconds: 300_000_000)

        if let localURL = await local {
            serverURL = localURL
            await finishConnection("Local ⚡")
            return
        }

        if await cloud {
            serverURL = APIConfig.baseURLString
            await finishConnection("Cloud ☁️")
        }
    }

    // =======================
    // RECONNECT
    // =======================

    func reconnect() {
        heartbeatTimer?.invalidate()
        socket?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        reconnectAttempts = 0
        start()
    }
}

// =======================
// MARK: - SYSTEM UI
// =======================

struct LilithSystemView: View {

    @StateObject private var system = LilithSystem.shared
    @State private var input = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                Text(system.status)
                    .foregroundStyle(.white.opacity(0.7))
                    .font(.system(size: 14))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(system.messages, id: \.self) { msg in
                            Text(msg)
                                .foregroundStyle(.white)
                                .padding(.horizontal)
                        }
                    }
                }

                HStack {
                    TextField("Say something...", text: $input)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)

                    Button("Send") {
                        system.send(input)
                        input = ""
                    }
                    .foregroundStyle(.white)
                }
                .padding()
            }
        }
        .onAppear {
            system.start()
        }
    }
}
