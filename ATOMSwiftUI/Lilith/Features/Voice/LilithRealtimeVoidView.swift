import SwiftUI
import Foundation
import Combine
import AVFoundation
#if canImport(WebRTC)
import WebRTC
#endif

// =======================
// MARK: - CORE IDENTITY
// =======================

struct LilithIdentity: Codable {
    let id: String
    let email: String
    let username: String
}

// =======================
// MARK: - CONTACT MODEL
// =======================

struct LilithContact: Identifiable, Codable {
    let id: String
    let name: String
    let lilithID: String
    let phone: String?
    let email: String?
}

// =======================
// MARK: - MESSAGE MODEL
// =======================

struct LilithVoiceMessage: Identifiable {
    let id = UUID()
    let from: String
    let to: String
    let content: String
    let timestamp: Date
}

// =======================
// MARK: - SOCIAL POST MODEL
// =======================

struct LilithPost: Identifiable {
    let id = UUID()
    let authorID: String
    let content: String
}

// =======================
// MARK: - PRESENCE MODEL
// =======================

enum PresenceStatus {
    case online
    case offline
    case typing
}

struct UserPresence: Identifiable {
    let id = UUID()
    var userID: String
    var status: PresenceStatus
}

@MainActor
final class PresenceManager: ObservableObject {
    @Published var users: [UserPresence] = []

    func setOnline(userID: String) {
        update(userID: userID, status: .online)
    }

    func setOffline(userID: String) {
        update(userID: userID, status: .offline)
    }

    func setTyping(userID: String) {
        update(userID: userID, status: .typing)
    }

    private func update(userID: String, status: PresenceStatus) {
        if let index = users.firstIndex(where: { $0.userID == userID }) {
            users[index].status = status
        } else {
            users.append(UserPresence(userID: userID, status: status))
        }
    }
}

// =======================
// MARK: - SYSTEM INTENT TYPES
// =======================

enum LilithIntentType {
    case message
    case call
    case post
    case unknown
}

// =======================
// MARK: - UNIFIED INTENT
// =======================

struct LilithIntent {
    var type: LilithIntentType
    var target: String?
    var content: String?
}

// =======================
// MARK: - INTENT ENGINE
// =======================

final class LilithIntentEngine {
    func parse(_ input: String) -> LilithIntent {
        let lower = input.lowercased()

        if lower.contains("text") || lower.contains("message") {
            let parts = input.split(separator: " ").map(String.init)
            return LilithIntent(
                type: .message,
                target: parts.count > 1 ? parts[1] : nil,
                content: parts.dropFirst(2).joined(separator: " ")
            )
        }

        if lower.contains("call") {
            let parts = input.split(separator: " ").map(String.init)
            return LilithIntent(
                type: .call,
                target: parts.count > 1 ? parts[1] : nil,
                content: nil
            )
        }

        if lower.contains("post") {
            return LilithIntent(type: .post, target: nil, content: input)
        }

        return LilithIntent(type: .unknown, target: nil, content: input)
    }
}

// =======================
// MARK: - SYSTEM ENGINE
// =======================

@MainActor
final class LilithSystemEngine: ObservableObject {
    @Published var messages: [LilithVoiceMessage] = []
    @Published var posts: [LilithPost] = []

    var identity: LilithIdentity?

    private let intentEngine = LilithIntentEngine()

    func handle(input: String) -> String {
        let intent = intentEngine.parse(input)

        switch intent.type {
        case .message:
            return handleMessage(intent)
        case .call:
            return handleCall(intent)
        case .post:
            return handlePost(intent)
        case .unknown:
            return "Lilith is processing your request..."
        }
    }

    private func handleMessage(_ intent: LilithIntent) -> String {
        guard let fromID = identity?.id else {
            return "No identity found"
        }

        guard let target = intent.target else {
            return "Who do you want to message?"
        }

        let message = LilithVoiceMessage(
            from: fromID,
            to: target,
            content: intent.content ?? "",
            timestamp: Date()
        )

        messages.append(message)
        return "Message sent to \(target)"
    }

    private func handleCall(_ intent: LilithIntent) -> String {
        guard let target = intent.target else {
            return "Who do you want to call?"
        }

        return "Calling \(target)..."
    }

    private func handlePost(_ intent: LilithIntent) -> String {
        guard let user = identity else {
            return "No identity"
        }

        let post = LilithPost(authorID: user.id, content: intent.content ?? "")
        posts.append(post)

        return "Post created"
    }
}

// =======================
// MARK: - VOID INTEGRATION
// =======================

struct FloatingResult: Identifiable {
    let id = UUID()
    let text: String
    let position: CGPoint
    let scale: CGFloat
    let rotation: Double
}

@MainActor
final class VoidSystemViewModel: ObservableObject {
    @Published var results: [FloatingResult] = []

    let system = LilithSystemEngine()

    func process(input: String, size: CGSize) {
        let output = system.handle(input: input)

        let xMin: CGFloat = 80
        let yMin: CGFloat = 200
        let xMax = max(xMin, size.width - 80)
        let yMax = max(yMin, size.height - 200)

        let result = FloatingResult(
            text: output,
            position: CGPoint(
                x: CGFloat.random(in: xMin...xMax),
                y: CGFloat.random(in: yMin...yMax)
            ),
            scale: CGFloat.random(in: 0.9...1.2),
            rotation: Double.random(in: -6...6)
        )

        withAnimation(.spring()) {
            results.append(result)
        }
    }
}

// =======================
// MARK: - REALTIME MESSAGE MODEL
// =======================

struct RTMessage: Identifiable, Codable {
    let id: String
    let from: String
    let to: String
    let content: String

    init(id: String = UUID().uuidString, from: String, to: String, content: String) {
        self.id = id
        self.from = from
        self.to = to
        self.content = content
    }
}

// =======================
// MARK: - PRODUCTION RTC CONFIG
// =======================

enum LilithRealtimeConfig {
    static let baseURL = "https://YOUR-RAILWAY-URL.up.railway.app"
    static let wsURL = "wss://YOUR-RAILWAY-URL.up.railway.app/ws"
}

#if canImport(WebRTC)
enum LilithRTCConfig {
    static func make() -> RTCConfiguration {
        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]),
            RTCIceServer(
                urlStrings: ["turn:your-turn-server.com:3478"],
                username: "user",
                credential: "pass"
            ),
        ]
        return config
    }
}

@MainActor
final class RealtimeWebRTCManager: NSObject, ObservableObject {
    var peerConnection: RTCPeerConnection?
    private let factory: RTCPeerConnectionFactory
    private var socket: URLSessionWebSocketTask?

    var userID: String = ""
    var targetID: String = ""

    @Published var localTrack: RTCVideoTrack?
    @Published var remoteTrack: RTCVideoTrack?
    @Published var isInCall = false

    private var videoSource: RTCVideoSource?
    private var capturer: RTCCameraVideoCapturer?

    override init() {
        RTCInitializeSSL()
        self.factory = RTCPeerConnectionFactory()
        super.init()
    }

    func connectSocket(server: String, userID: String) {
        self.userID = userID
        guard let url = URL(string: "\(server)/ws/\(userID)") else { return }

        socket?.cancel(with: .goingAway, reason: nil)
        socket = URLSession.shared.webSocketTask(with: url)
        socket?.resume()
        listen()
    }

    func disconnectSocket() {
        socket?.cancel(with: .goingAway, reason: nil)
        socket = nil
    }

    func listen() {
        socket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .failure:
                    break
                case .success(let msg):
                    if case let .string(text) = msg {
                        self.handleSignal(text)
                    }
                }

                self.listen()
            }
        }
    }

    func handleSignal(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return
        }

        let type = json["type"] as? String

        if type == "offer" || type == "webrtc_offer" {
            // TODO: set remote offer and create/send answer.
        }

        if type == "answer" || type == "webrtc_answer" {
            // TODO: set remote answer on peer connection.
        }

        if type == "ice" || type == "webrtc_ice" {
            // TODO: parse/add remote ICE candidate.
        }
    }

    func createPeerConnection() {
        let config = LilithRTCConfig.make()
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)

        peerConnection = factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: nil
        )
    }

    func sendSignal(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let string = String(data: data, encoding: .utf8)
        else {
            return
        }

        socket?.send(.string(string)) { _ in }
    }

    func startCall(targetID: String) {
        self.targetID = targetID
        isInCall = true
        createPeerConnection()
        startLocalVideo()
    }

    func endCall() {
        capturer?.stopCapture()
        peerConnection?.close()
        localTrack = nil
        remoteTrack = nil
        isInCall = false
    }

    private func startLocalVideo() {
        AVCaptureDevice.requestAccess(for: .video) { _ in }
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { _ in }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }

        videoSource = factory.videoSource()
        guard let videoSource else { return }

        capturer = RTCCameraVideoCapturer(delegate: videoSource)

        guard let camera = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == .front })
            ?? RTCCameraVideoCapturer.captureDevices().first,
            let format = RTCCameraVideoCapturer.supportedFormats(for: camera).first
        else {
            return
        }

        let fps = Int(format.videoSupportedFrameRateRanges.first?.maxFrameRate ?? 30)
        capturer?.startCapture(with: camera, format: format, fps: max(1, min(fps, 30)))
        localTrack = factory.videoTrack(with: videoSource, trackId: "local")
    }
}
#endif

// =======================
// MARK: - WEBRTC VIDEO VIEW
// =======================

#if canImport(WebRTC)
struct RealtimeRTCVideoView: UIViewRepresentable {
    var track: RTCVideoTrack?

    func makeUIView(context: Context) -> RTCMTLVideoView {
        let view = RTCMTLVideoView()
        view.videoContentMode = .scaleAspectFill
        return view
    }

    func updateUIView(_ uiView: RTCMTLVideoView, context: Context) {
        track?.add(uiView)
    }
}
#endif

// =======================
// MARK: - SOCKET MANAGER
// =======================

@MainActor
final class RealtimeSocketManager: ObservableObject {
    private var webSocket: URLSessionWebSocketTask?
    @Published var messages: [RTMessage] = []

    private(set) var userID: String = ""

    func connect(url: String, userID: String) {
        self.userID = userID

        guard let wsURL = URL(string: url) else { return }

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = URLSession.shared.webSocketTask(with: wsURL)
        webSocket?.resume()

        listen()
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
    }

    private func listen() {
        webSocket?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                switch result {
                case .failure:
                    break
                case .success(let message):
                    if case let .string(text) = message,
                       let data = text.data(using: .utf8),
                       let msg = try? JSONDecoder().decode(RTMessage.self, from: data) {
                        self.messages.append(msg)
                    }
                }

                self.listen()
            }
        }
    }

    func send(_ message: RTMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let string = String(data: data, encoding: .utf8) else { return }

        webSocket?.send(.string(string)) { _ in }
    }
}

// =======================
// MARK: - WEBRTC CALL MANAGER
// =======================

@MainActor
final class RealtimeCallManager: ObservableObject {
    #if canImport(WebRTC)
    private let manager = RealtimeWebRTCManager()

    @Published var localTrack: RTCVideoTrack?
    @Published var remoteTrack: RTCVideoTrack?
    @Published var isInCall = false

    private var cancellables: Set<AnyCancellable> = []

    init() {
        manager.$localTrack
            .sink { [weak self] in self?.localTrack = $0 }
            .store(in: &cancellables)
        manager.$remoteTrack
            .sink { [weak self] in self?.remoteTrack = $0 }
            .store(in: &cancellables)
        manager.$isInCall
            .sink { [weak self] in self?.isInCall = $0 }
            .store(in: &cancellables)
    }
    #else
    @Published var isInCall = false

    init() {}
    #endif

    func startCall() {
        #if canImport(WebRTC)
        manager.startCall(targetID: "user2")
        #else
        isInCall = true
        #endif
    }

    func connectSocket(wsURL: String, userID: String) {
        #if canImport(WebRTC)
        manager.connectSocket(server: wsURL, userID: userID)
        #endif
    }

    func disconnectSocket() {
        #if canImport(WebRTC)
        manager.disconnectSocket()
        #endif
    }

    func endCall() {
        #if canImport(WebRTC)
        manager.endCall()
        #endif
        isInCall = false
    }
}

// =======================
// MARK: - VIEW MODEL
// =======================

@MainActor
final class RealtimeViewModel: ObservableObject {
    @Published var results: [FloatingResult] = []

    let socket = RealtimeSocketManager()
    let callManager = RealtimeCallManager()
    let presence = PresenceManager()
    let localSystem = VoidSystemViewModel()

    private var cancellables: Set<AnyCancellable> = []

    var userID: String = "user1"

    func connect() {
        let base = UserDefaults.standard.string(forKey: "BackendURLOverride")
            ?? UserDefaults.standard.string(forKey: "serverURL")
            ?? APIConfig.baseURLString
        let wsBase = websocketBase(from: base)
        socket.connect(url: "\(wsBase)/ws/\(userID)", userID: userID)
        callManager.connectSocket(wsURL: wsBase, userID: userID)

        socket.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msgs in
                guard let self, let last = msgs.last else { return }
                self.spawnResult("Incoming: \(last.content)", size: CGSize(width: 420, height: 900))
            }
            .store(in: &cancellables)
    }

    func disconnect() {
        socket.disconnect()
        callManager.disconnectSocket()
    }

    func runIntent(_ input: String, size: CGSize) {
        let lower = input.lowercased()

        if lower.contains("call") {
            startCall(target: "user2", size: size)
            return
        }

        if lower.contains("online") {
            presence.setOnline(userID: "user2")
            spawnResult("user2 is online", size: size)
            return
        }

        if lower.contains("typing") {
            presence.setTyping(userID: "user2")
            spawnResult("user2 is typing...", size: size)
            return
        }

        localSystem.process(input: input, size: size)
        if let last = localSystem.results.last {
            results.append(last)
        }
    }

    func sendMessage(to: String, text: String, size: CGSize) {
        let msg = RTMessage(from: userID, to: to, content: text)
        socket.send(msg)
        spawnResult("Sent: \(text)", size: size)
    }

    func startCall(target: String, size: CGSize) {
        callManager.startCall()
        spawnResult("Calling \(target)...", size: size)
    }

    func spawnResult(_ text: String, size: CGSize) {
        let xMin: CGFloat = 80
        let yMin: CGFloat = 200
        let xMax = max(xMin, size.width - 80)
        let yMax = max(yMin, size.height - 200)

        let result = FloatingResult(
            text: text,
            position: CGPoint(
                x: CGFloat.random(in: xMin...xMax),
                y: CGFloat.random(in: yMin...yMax)
            ),
            scale: 1,
            rotation: Double.random(in: -5...5)
        )

        withAnimation {
            results.append(result)
        }
    }

    private func websocketBase(from httpBase: String) -> String {
        let trimmed = httpBase.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("https://") {
            return "wss://" + trimmed.dropFirst("https://".count)
        }
        if trimmed.hasPrefix("http://") {
            return "ws://" + trimmed.dropFirst("http://".count)
        }
        if trimmed.hasPrefix("ws://") || trimmed.hasPrefix("wss://") {
            return trimmed
        }
        return "ws://\(trimmed)"
    }
}

// =======================
// MARK: - VOID VIEW (REALTIME)
// =======================

private struct RealtimeResultBubble: View {
    let result: FloatingResult

    var body: some View {
        Text(result.text)
            .padding(14)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(result.scale)
            .rotationEffect(.degrees(result.rotation))
    }
}

struct FloatingContainer: View {
    @Binding var results: [FloatingResult]

    var body: some View {
        ZStack {
            ForEach(results) { item in
                RealtimeResultBubble(result: item)
                    .position(item.position)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

struct RealtimeCallView: View {
    @ObservedObject var callManager: RealtimeCallManager

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            #if canImport(WebRTC)
            if let remote = callManager.remoteTrack {
                RealtimeRTCVideoView(track: remote)
                    .ignoresSafeArea()
            }

            VStack {
                HStack {
                    Spacer()

                    if let local = callManager.localTrack {
                        RealtimeRTCVideoView(track: local)
                            .frame(width: 120, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding()
                    }
                }
                Spacer()
            }
            #else
            VStack(spacing: 12) {
                Text("Video Call")
                    .font(.title2.weight(.semibold))
                Text("WebRTC framework not linked in this target.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            #endif

            VStack {
                Spacer()

                Button {
                    callManager.endCall()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .padding(.bottom, 50)
            }
        }
    }
}

struct RealtimeVoidView: View {
    @StateObject private var vm = RealtimeViewModel()
    @State private var input = ""

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                FloatingContainer(results: $vm.results)

                VStack {
                    Spacer()

                    HStack(spacing: 10) {
                        TextField("Ask Lilith...", text: $input)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)

                        Button("Send") {
                            vm.sendMessage(to: "user2", text: input, size: geo.size)
                            input = ""
                        }

                        Button("Call") {
                            vm.startCall(target: "user2", size: geo.size)
                        }

                        Button("Intent") {
                            vm.runIntent(input, size: geo.size)
                            input = ""
                        }
                    }
                    .padding()
                }

                if vm.callManager.isInCall {
                    RealtimeCallView(callManager: vm.callManager)
                }
            }
        }
        .onAppear {
            vm.connect()
        }
        .onDisappear {
            vm.disconnect()
        }
    }
}

#Preview {
    RealtimeVoidView()
}
