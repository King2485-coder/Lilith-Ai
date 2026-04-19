import SwiftUI
import WebKit

// MARK: - Floating Tool View
// Any tool destination rendered as a floating window inside the void.

struct FloatingToolView: View {
    let tool: FloatingTool
    let onDismiss: () -> Void
    let onBringToFront: () -> Void
    let onUpdatePosition: (CGPoint) -> Void
    let onUpdateSize: (CGSize) -> Void
    let onToggleExpanded: () -> Void
    let onSpawnResult: (ResultPayload) -> Void
    let onLoadConversation: (String) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isResizing: Bool = false
    @State private var isDraggingView: Bool = false

    var body: some View {
        ZStack {
            if tool.isExpanded {
                expandedOverlay
            }

            cardContent
                .frame(width: tool.size.width, height: tool.size.height)
                .position(
                    x: tool.position.x + dragOffset.width,
                    y: tool.position.y + dragOffset.height
                )
                .zIndex(Double(tool.zIndex))
        }
    }

    private var cardContent: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.04).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(white: 0.14).opacity(0.5), lineWidth: 0.5)
                )

            // Tool content
            toolContent
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Controls overlay
            controlsOverlay
        }
        .shadow(color: Color.black.opacity(0.5), radius: isDraggingView ? 24 : 16, x: 0, y: 8)
        .scaleEffect(isDraggingView ? 1.02 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDraggingView)
        .modifier(AmbientDriftModifier(phase: tool.driftPhase))
        .gesture(
            DragGesture()
                .onChanged { value in
                    if !isResizing {
                        isDraggingView = true
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    isDraggingView = false
                    let newX = tool.position.x + value.translation.width
                    let newY = tool.position.y + value.translation.height
                    onUpdatePosition(CGPoint(x: newX, y: newY))
                    dragOffset = .zero
                }
        )
        .onTapGesture(count: 2) {
            onToggleExpanded()
        }
        .onTapGesture {
            onBringToFront()
        }
    }

    @ViewBuilder
    private var toolContent: some View {
        switch tool.destination {
        case .image:
            ImageGenView { payload in
                onSpawnResult(payload)
            }
        case .video:
            VideoView { payload in
                onSpawnResult(payload)
            }
        case .clone:
            CloneView()
        case .code:
            IDEView()
        case .projects:
            ProjectsView()
        case .history:
            HistoryView { conversationId in
                onLoadConversation(conversationId)
            }
        case .web:
            FloatingWebView()
        case .vault:
            VaultView()
        default:
            GenericToolPlaceholder(destination: tool.destination)
        }
    }

    private var controlsOverlay: some View {
        ZStack {
            VStack {
                HStack {
                    Button(action: onToggleExpanded) {
                        Image(systemName: tool.isExpanded
                            ? "arrow.down.right.arrow.up.left"
                            : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(white: 0.55))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color(white: 0.08).opacity(0.92)))
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 6)
                    .padding(.top, 6)

                    Spacer()

                    Text(tool.destination.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.4))
                        .padding(.top, 6)

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(white: 0.55))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color(white: 0.08).opacity(0.92)))
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 6)
                    .padding(.top, 6)
                }

                Spacer()

                HStack {
                    Spacer()
                    resizeHandle
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                }
            }
        }
    }

    private var resizeHandle: some View {
        Circle()
            .fill(Color(white: 0.35).opacity(0.6))
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(Color(white: 0.5).opacity(0.4), lineWidth: 0.5)
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isResizing = true
                        let deltaX = value.location.x - value.startLocation.x
                        let deltaY = value.location.y - value.startLocation.y
                        let newWidth = max(200, min(UIScreen.main.bounds.width - 32, tool.size.width + deltaX))
                        let newHeight = max(160, min(UIScreen.main.bounds.height - 32, tool.size.height + deltaY))
                        onUpdateSize(CGSize(width: newWidth, height: newHeight))
                    }
                    .onEnded { _ in
                        isResizing = false
                    }
            )
    }

    private var expandedOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onToggleExpanded()
                }

            toolContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
        }
        .zIndex(1000)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }
}

// MARK: - Generic Tool Placeholder

struct GenericToolPlaceholder: View {
    let destination: WorkspaceDestination

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: destination.icon)
                .font(.system(size: 36))
                .foregroundStyle(Color(white: 0.25))

            Text(destination.title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(white: 0.7))

            Text(destination.subtitle)
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Floating Web View

struct FloatingWebView: View {
    @State private var urlString: String = "https://"
    @State private var activeURL: URL? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Address bar
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.4))

                TextField("Enter URL…", text: $urlString)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(white: 0.8))
                    .tint(Color(white: 0.5))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .keyboardType(.URL)
                    .onSubmit {
                        loadURL()
                    }

                Button(action: loadURL) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(white: 0.6))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(white: 0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color(white: 0.14).opacity(0.3), lineWidth: 0.5)
                    )
            )
            .padding(10)

            // Web content
            if let url = activeURL {
                WebView(url: url)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "safari")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(white: 0.2))
                    Text("Nexus Browser")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(white: 0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func loadURL() {
        var text = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.hasPrefix("http://") && !text.hasPrefix("https://") {
            text = "https://\(text)"
        }
        if let url = URL(string: text) {
            activeURL = url
        }
    }
}

// MARK: - WebView (WKWebView wrapper)

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = UIColor.black
        webView.isOpaque = false
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }
}
