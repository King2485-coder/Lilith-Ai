import SwiftUI

// MARK: - SETTINGS MODEL

@MainActor
final class ServerSettings: ObservableObject {
    @Published var serverURL: String {
        didSet {
            UserDefaults.standard.set(serverURL, forKey: "serverURL")
            UserDefaults.standard.set(serverURL, forKey: "BackendURLOverride")
        }
    }

    @Published var status: ConnectionStatus = .unknown

    init() {
        if let override = UserDefaults.standard.string(forKey: "BackendURLOverride"),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.serverURL = override
        } else {
            self.serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? APIConfig.baseURLString
        }
    }

    enum ConnectionStatus {
        case unknown
        case checking
        case connected
        case failed
    }
}

// MARK: - API CLIENT

struct ServerSettingsAPIClient {
    static let shared = ServerSettingsAPIClient()

    func testConnection(baseURL: String) async -> Bool {
        guard let url = URL(string: sanitized(baseURL) + "/") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode == 200
        } catch {
            return false
        }
    }

    func request(path: String, baseURL: String) async -> String {
        guard let url = URL(string: sanitized(baseURL) + path) else {
            return "Invalid URL"
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return String(data: data, encoding: .utf8) ?? "No response"
        } catch {
            return "Connection failed"
        }
    }

    private func sanitized(_ baseURL: String) -> String {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }
}

// MARK: - SERVER SETTINGS VIEW

struct ServerSettingsView: View {
    @ObservedObject var settings: ServerSettings
    @State private var tempURL: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                Text("Lilith Server")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)

                VStack(spacing: 12) {
                    TextField("http://192.168.x.x:8000", text: $tempURL)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                        .foregroundStyle(.white)

                    Button("Save") {
                        let trimmed = tempURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        settings.serverURL = trimmed
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(20)
                }

                Button {
                    Task {
                        settings.status = .checking
                        let success = await ServerSettingsAPIClient.shared.testConnection(baseURL: settings.serverURL)
                        await MainActor.run {
                            settings.status = success ? .connected : .failed
                        }
                    }
                } label: {
                    Text("Test Connection")
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(20)
                }

                statusView
                Spacer()
            }
            .padding()
        }
        .onAppear {
            tempURL = settings.serverURL
        }
    }

    @ViewBuilder
    var statusView: some View {
        switch settings.status {
        case .unknown:
            Text("No connection tested")
                .foregroundStyle(.gray)

        case .checking:
            Text("Checking...")
                .foregroundStyle(.yellow)

        case .connected:
            Text("Connected")
                .foregroundStyle(.green)

        case .failed:
            Text("Connection failed")
                .foregroundStyle(.red)
        }
    }
}

// MARK: - QUICK ACCESS BUTTON

struct SettingsButton: View {
    @Binding var showSettings: Bool

    var body: some View {
        VStack {
            HStack {
                Spacer()

                Button {
                    showSettings.toggle()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(12)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .padding()
            }

            Spacer()
        }
    }
}