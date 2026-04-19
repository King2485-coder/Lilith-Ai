import SwiftUI
import AVKit

// MARK: - Center Result View
// Results manifest from the void — no lists, no stacked cards, just emergence.

struct CenterResultView: View {
    @ObservedObject var viewModel: ChatViewModel

    @State private var manifestScale: CGFloat = 0.82
    @State private var manifestOpacity: Double = 0
    @State private var manifestBlur: CGFloat = 10

    var body: some View {
        ZStack {
            if let result = viewModel.activeResult {
                resultContent(result)
                    .scaleEffect(manifestScale)
                    .opacity(manifestOpacity)
                    .blur(radius: manifestBlur)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: viewModel.activeResult) { newValue in
            if newValue != nil {
                // Begin emergence from void center
                manifestScale = 0.82
                manifestOpacity = 0
                manifestBlur = 10
                withAnimation(.easeOut(duration: 0.55)) {
                    manifestScale = 1.0
                    manifestOpacity = 1
                    manifestBlur = 0
                }
            } else {
                // Collapse back into void
                withAnimation(.easeIn(duration: 0.3)) {
                    manifestScale = 0.88
                    manifestOpacity = 0
                    manifestBlur = 6
                }
            }
        }
    }

    @ViewBuilder
    private func resultContent(_ result: ResultPayload) -> some View {
        switch result.type {
        case .image:
            ImageResultView(result: result) {
                withAnimation(.easeIn(duration: 0.3)) {
                    viewModel.activeResult = nil
                }
            }
        case .video:
            VideoResultView(result: result) {
                withAnimation(.easeIn(duration: 0.3)) {
                    viewModel.activeResult = nil
                }
            }
        case .text:
            TextResultView(result: result) {
                withAnimation(.easeIn(duration: 0.3)) {
                    viewModel.activeResult = nil
                }
            }
        case .media:
            MediaResultView(result: result) {
                withAnimation(.easeIn(duration: 0.3)) {
                    viewModel.activeResult = nil
                }
            }
        }
    }
}

// MARK: - Image Result

struct ImageResultView: View {
    let result: ResultPayload
    let onDismiss: () -> Void

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if result.status == .pending || isLoading {
                PendingIndicator()
            }

            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 520, maxHeight: 520)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.55), radius: 60, x: 0, y: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color(red: 0.18, green: 0.23, blue: 0.28).opacity(0.25), lineWidth: 0.5)
                    )
            }
        }
        .overlay(alignment: .topTrailing) {
            if image != nil || result.imageData != nil {
                VoidDismissButton(action: onDismiss)
            }
        }
        .onAppear {
            loadImage()
        }
    }

    private func loadImage() {
        isLoading = true

        // Base64 path
        if let base64 = result.imageData, !base64.isEmpty {
            if let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
               let uiImage = UIImage(data: data) {
                image = uiImage
                isLoading = false
            } else {
                isLoading = false
            }
            return
        }

        // URL path
        guard let url = result.url else {
            isLoading = false
            return
        }

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let loadedImage = UIImage(data: data) {
                    await MainActor.run {
                        self.image = loadedImage
                        self.isLoading = false
                    }
                } else {
                    await MainActor.run { isLoading = false }
                }
            } catch {
                await MainActor.run { isLoading = false }
            }
        }
    }
}

// MARK: - Video Result

struct VideoResultView: View {
    let result: ResultPayload
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            if result.status == .pending {
                PendingIndicator()
            }

            if let url = result.url {
                VStack(spacing: 14) {
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(width: 480, height: 270)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: Color.black.opacity(0.55), radius: 50, x: 0, y: 25)

                    HStack {
                        Link(destination: url) {
                            Label("Open", systemImage: "arrow.up.right.square")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(LilithTheme.accentA)
                        }
                        Spacer()
                        VoidDismissButton(action: onDismiss)
                    }
                    .padding(.horizontal, 4)
                }
                .frame(width: 480)
            } else if !result.content.isEmpty && result.status == .complete {
                TextResultContent(content: result.content)
                    .overlay(alignment: .topTrailing) {
                        VoidDismissButton(action: onDismiss)
                    }
            }
        }
    }
}

// MARK: - Text Result

struct TextResultView: View {
    let result: ResultPayload
    let onDismiss: () -> Void

    var body: some View {
        TextResultContent(content: result.content)
            .overlay(alignment: .topTrailing) {
                VoidDismissButton(action: onDismiss)
            }
    }
}

struct TextResultContent: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(red: 0.30, green: 0.50, blue: 0.70).opacity(0.5))
                    .frame(width: 6, height: 6)

                Text("Lilith")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(red: 0.38, green: 0.48, blue: 0.58))

                Spacer()
            }

            Text(content)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .lineSpacing(4)
                .foregroundStyle(Color(red: 0.82, green: 0.87, blue: 0.92))
        }
        .padding(24)
        .frame(maxWidth: 480, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.04, green: 0.05, blue: 0.06).opacity(0.82))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(red: 0.16, green: 0.20, blue: 0.26).opacity(0.25), lineWidth: 0.5)
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 45, x: 0, y: 22)
    }
}

// MARK: - Media Result

struct MediaResultView: View {
    let result: ResultPayload
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if result.status == .pending {
                PendingIndicator()
            } else {
                Image(systemName: "film")
                    .font(.system(size: 48))
                    .foregroundStyle(Color(red: 0.38, green: 0.48, blue: 0.58))

                Text(result.content)
                    .font(.system(size: 14))
                    .foregroundStyle(Color(red: 0.55, green: 0.60, blue: 0.65))

                VoidDismissButton(action: onDismiss)
            }
        }
        .padding(36)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.04, green: 0.05, blue: 0.06).opacity(0.82))
        )
        .shadow(color: Color.black.opacity(0.45), radius: 45, x: 0, y: 22)
    }
}

// MARK: - Pending Indicator

struct PendingIndicator: View {
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(red: 0.22, green: 0.32, blue: 0.42).opacity(0.18), lineWidth: 1)
                .frame(width: 72, height: 72)

            ArcShape(startAngle: .degrees(0), endAngle: .degrees(110))
                .stroke(
                    Color(red: 0.38, green: 0.52, blue: 0.68).opacity(0.55),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .frame(width: 72, height: 72)
                .rotationEffect(.degrees(rotation))
                .onAppear {
                    withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                        rotation = 360
                    }
                }

            Text("Creating...")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color(red: 0.38, green: 0.48, blue: 0.58))
                .offset(y: 50)
        }
    }
}

// MARK: - Arc Shape

struct ArcShape: Shape {
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

// MARK: - Dismiss Button

struct VoidDismissButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color(red: 0.50, green: 0.55, blue: 0.60))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color(red: 0.06, green: 0.07, blue: 0.08).opacity(0.92))
                )
        }
        .buttonStyle(.plain)
    }
}
