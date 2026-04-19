import SwiftUI
import AVKit

// MARK: - Ambient Drift Modifier

struct AmbientDriftModifier: ViewModifier {
    let phase: Double
    @State private var time: Double = 0

    func body(content: Content) -> some View {
        content
            .offset(
                x: sin(time * 0.4 + phase) * 1.5,
                y: cos(time * 0.3 + phase + 1.0) * 1.0
            )
            .onAppear {
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    time = Double.pi * 2
                }
            }
    }
}

// MARK: - Floating Object View

struct FloatingObjectView: View {
    let object: FloatingObject
    let onDismiss: () -> Void
    let onBringToFront: () -> Void
    let onUpdatePosition: (CGPoint) -> Void
    let onUpdateSize: (CGSize) -> Void
    let onToggleExpanded: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var isResizing: Bool = false
    @State private var isDraggingView: Bool = false

    var body: some View {
        ZStack {
            if object.isExpanded {
                expandedOverlay
            }

            cardContent
                .frame(width: object.size.width, height: object.size.height)
                .position(
                    x: object.position.x + dragOffset.width,
                    y: object.position.y + dragOffset.height
                )
                .zIndex(Double(object.zIndex))
        }
    }

    // MARK: - Card Content

    private var cardContent: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.05).opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(white: 0.14).opacity(0.5), lineWidth: 0.5)
                )

            // Content
            payloadContent
                .padding(8)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Controls overlay
            controlsOverlay
        }
        .shadow(color: Color.black.opacity(0.5), radius: isDraggingView ? 24 : 16, x: 0, y: 8)
        .scaleEffect(isDraggingView ? 1.03 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isDraggingView)
        .modifier(AmbientDriftModifier(phase: object.driftPhase))
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
                    let newX = object.position.x + value.translation.width
                    let newY = object.position.y + value.translation.height
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

    // MARK: - Payload Content

    @ViewBuilder
    private var payloadContent: some View {
        switch object.payload.type {
        case .image:
            FloatingImageContent(payload: object.payload)
        case .video:
            FloatingVideoContent(payload: object.payload)
        case .text:
            FloatingTextContent(payload: object.payload)
        case .media:
            FloatingMediaContent(payload: object.payload)
        }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        ZStack {
            // Top-left: expand
            VStack {
                HStack {
                    Button(action: onToggleExpanded) {
                        Image(systemName: object.isExpanded
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

                    // Top-right: dismiss
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

                // Bottom-right: resize handle
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
                        let newWidth = max(160, min(UIScreen.main.bounds.width - 32, object.size.width + deltaX))
                        let newHeight = max(120, min(UIScreen.main.bounds.height - 32, object.size.height + deltaY))
                        onUpdateSize(CGSize(width: newWidth, height: newHeight))
                    }
                    .onEnded { _ in
                        isResizing = false
                    }
            )
    }

    // MARK: - Expanded Overlay

    private var expandedOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onToggleExpanded()
                }

            expandedContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
        }
        .zIndex(1000)
        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch object.payload.type {
        case .image:
            ExpandedImageContent(payload: object.payload, onDismiss: onToggleExpanded)
        case .video:
            ExpandedVideoContent(payload: object.payload, onDismiss: onToggleExpanded)
        case .text:
            ExpandedTextContent(payload: object.payload, onDismiss: onToggleExpanded)
        case .media:
            ExpandedMediaContent(payload: object.payload, onDismiss: onToggleExpanded)
        }
    }
}

// MARK: - Floating Content Views

struct FloatingImageContent: View {
    let payload: ResultPayload
    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if isLoading {
                FloatingPendingIndicator()
            }
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        }
        .onAppear { loadImage() }
    }

    private func loadImage() {
        isLoading = true
        if let base64 = payload.imageData, !base64.isEmpty {
            if let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
               let uiImage = UIImage(data: data) {
                image = uiImage
            }
            isLoading = false
            return
        }
        guard let url = payload.url else { isLoading = false; return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let loaded = UIImage(data: data) {
                    await MainActor.run { image = loaded; isLoading = false }
                } else {
                    await MainActor.run { isLoading = false }
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

struct FloatingVideoContent: View {
    let payload: ResultPayload

    var body: some View {
        ZStack {
            if payload.status == .pending {
                FloatingPendingIndicator()
            } else if let url = payload.url {
                VideoPlayer(player: AVPlayer(url: url))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                Text(payload.content)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.6))
            }
        }
    }
}

struct FloatingTextContent: View {
    let payload: ResultPayload

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color(white: 0.5).opacity(0.4))
                        .frame(width: 5, height: 5)
                    Text("Lilith")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                    Spacer()
                }

                Text(payload.content)
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .lineSpacing(3)
                    .foregroundStyle(Color(white: 0.82))
            }
            .padding(12)
        }
    }
}

struct FloatingMediaContent: View {
    let payload: ResultPayload

    var body: some View {
        VStack(spacing: 16) {
            if payload.status == .pending {
                FloatingPendingIndicator()
            } else {
                Image(systemName: "film")
                    .font(.system(size: 36))
                    .foregroundStyle(Color(white: 0.4))
                Text(payload.content)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Expanded Content Views

struct ExpandedImageContent: View {
    let payload: ResultPayload
    let onDismiss: () -> Void
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                FloatingImageContent(payload: payload)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(white: 0.15).opacity(0.9)))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
        .onAppear {
            if let base64 = payload.imageData, !base64.isEmpty,
               let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
               let uiImage = UIImage(data: data) {
                image = uiImage
            } else if let url = payload.url {
                Task {
                    do {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let loaded = UIImage(data: data) {
                            await MainActor.run { image = loaded }
                        }
                    } catch { }
                }
            }
        }
    }
}

struct ExpandedVideoContent: View {
    let payload: ResultPayload
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            if let url = payload.url {
                VideoPlayer(player: AVPlayer(url: url))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                FloatingVideoContent(payload: payload)
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(white: 0.15).opacity(0.9)))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
    }
}

struct ExpandedTextContent: View {
    let payload: ResultPayload
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.05).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(white: 0.14).opacity(0.5), lineWidth: 0.5)
                )

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(white: 0.5).opacity(0.4))
                            .frame(width: 6, height: 6)
                        Text("Lilith")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(white: 0.45))
                        Spacer()
                        Button(action: onDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Color(white: 0.55))
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color(white: 0.08).opacity(0.92)))
                        }
                        .buttonStyle(.plain)
                    }

                    Text(payload.content)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .lineSpacing(4)
                        .foregroundStyle(Color(white: 0.85))
                }
                .padding(24)
            }
        }
        .frame(maxWidth: 600, maxHeight: .infinity)
    }
}

struct ExpandedMediaContent: View {
    let payload: ResultPayload
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            FloatingMediaContent(payload: payload)
                .frame(maxWidth: 400, maxHeight: 400)

            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(white: 0.15).opacity(0.9)))
                    }
                    .buttonStyle(.plain)
                    .padding()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Pending Indicator

struct FloatingPendingIndicator: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(white: 0.25).opacity(0.2), lineWidth: 1)
                .frame(width: 48, height: 48)

            FloatingArcShape(startAngle: .degrees(0), endAngle: .degrees(110))
                .stroke(
                    Color(white: 0.5).opacity(0.5),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("Creating...")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(white: 0.4))
                .offset(y: 36)
        }
    }
}

// MARK: - Arc Shape

struct FloatingArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
