import SwiftUI
import Network

// =======================
// MARK: - SERVER MANAGER (FAST)
// =======================

@MainActor
final class ServerManager: ObservableObject {

    static let shared = ServerManager()

    @Published var activeURL: String = ""
    @Published var status: String = "Connecting..."

    private let bonjourType = "_http._tcp."
    private let bonjourName = "lilith"
    private let bonjourPort = 8000

    private var browser: NWBrowser?

    // =======================
    // START
    // =======================

    func start() {
        Task {
            await connectFast()
        }
    }

    // =======================
    // FAST CONNECTION FLOW
    // =======================

    func connectFast() async {
        // 1. Try cached instantly
        if let saved = UserDefaults.standard.string(forKey: "BackendURLOverride"),
           !saved.isEmpty, await test(saved) {
            setActive(saved, "Connected ⚡")
            return
        }

        // 2. Bonjour and cloud in parallel — first responder wins
        async let localURL = discoverBonjour()
        let productionURL = APIConfig.baseURLString
        async let cloudUp = test(productionURL)

        if let url = await localURL {
            setActive(url, "Local ⚡")
            return
        }

        if await cloudUp {
            setActive(productionURL, "Cloud ☁️")
            return
        }

        status = "No server found ❌"
    }

    // =======================
    // TEST URL
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
    // BONJOUR DISCOVERY (INSTANT LAN)
    // =======================

    nonisolated func discoverBonjour() async -> String? {
        let bonjourName = self.bonjourName
        let bonjourPort = self.bonjourPort

        return await withCheckedContinuation { continuation in
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

            let resume: @Sendable (String?) -> Void = { url in
                if resumeState.claim() {
                    continuation.resume(returning: url)
                }
            }

            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let browser = NWBrowser(
                for: .bonjour(type: "_http._tcp.", domain: "local."),
                using: params
            )

            browser.stateUpdateHandler = { state in
                if case .failed = state {
                    resume(nil)
                }
            }

            browser.browseResultsChangedHandler = { results, _ in
                for result in results {
                    if case let .service(name, _, _, _) = result.endpoint,
                       name.lowercased().contains(bonjourName) {
                        // Resolve endpoint to get the actual IP.
                        let connection = NWConnection(to: result.endpoint, using: .tcp)
                        connection.stateUpdateHandler = { connState in
                            if case .ready = connState,
                               let path = connection.currentPath,
                               let remote = path.remoteEndpoint,
                               case let .hostPort(host, _) = remote {
                                let ip = "\(host)"
                                    .replacingOccurrences(of: "%.*", with: "", options: .regularExpression)
                                resume("http://\(ip):\(bonjourPort)")
                                connection.cancel()
                            }
                            if case .failed = connState {
                                connection.cancel()
                            }
                        }
                        connection.start(queue: .global())
                        return
                    }
                }
            }

            browser.start(queue: .global())

            // Timeout safety — cancel browser so it doesn't linger.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
                browser.cancel()
                resume(nil)
            }
        }
    }

    // =======================
    // SET ACTIVE
    // =======================

    func setActive(_ url: String, _ label: String) {
        activeURL = url
        status = label
        UserDefaults.standard.set(url, forKey: "BackendURLOverride")
    }
}

// =======================
// MARK: - API CLIENT USING AUTO SERVER
// =======================

enum LilithAPI {

    static func request(path: String) async -> String {
        let base = await ServerManager.shared.activeURL

        guard let url = URL(string: "\(base)\(path)") else {
            return "Invalid URL"
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return String(data: data, encoding: .utf8) ?? "No response"
        } catch {
            return "Connection failed"
        }
    }
}

// =======================
// MARK: - STATUS VIEW
// =======================

struct ServerStatusView: View {

    @ObservedObject var server = ServerManager.shared

    var body: some View {
        Text(server.status)
            .font(.system(size: 14))
            .foregroundStyle(.white.opacity(0.6))
    }
}
