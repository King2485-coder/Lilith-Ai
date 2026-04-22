import SwiftUI
import MetalKit

struct LilithVoiceResult: Identifiable {
    let id = UUID()
    let text: String
    let position: CGPoint
    let scale: CGFloat
    let rotation: Double
}

@MainActor
final class LilithVoiceConsoleViewModel: ObservableObject {
    @Published var results: [LilithVoiceResult] = []
    @Published var isLoading = false
    @Published private(set) var conversationId: String?

    private let assistant = LilithVoiceAssistantService()

    func submit(text: String, size: CGSize, speech: LilithSpeechManager, stateManager: LilithStateManager) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        stateManager.set(.thinking)

        Task {
            let reply = await assistant.respond(to: trimmed, conversationId: conversationId)
            let result = LilithVoiceResult(
                text: reply.combinedText,
                position: randomPosition(in: size),
                scale: CGFloat.random(in: 0.92...1.16),
                rotation: Double.random(in: -6...6)
            )

            await MainActor.run {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                    self.results.append(result)
                    self.isLoading = false
                }
                self.conversationId = reply.conversationId
                stateManager.set(.responding)
                speech.speak(reply.assistantText)
            }
        }
    }

    private func randomPosition(in size: CGSize) -> CGPoint {
        let xMin: CGFloat = 90
        let yMin: CGFloat = 170
        let xMax = max(xMin, size.width - 90)
        let yMax = max(yMin, size.height - 220)

        return CGPoint(
            x: CGFloat.random(in: xMin...xMax),
            y: CGFloat.random(in: yMin...yMax)
        )
    }
}

private struct LilithVoiceBubbleView: View {
    let result: LilithVoiceResult
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        Text(result.text)
            .font(.body)
            .foregroundStyle(.white)
            .padding(18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .shadow(color: .black.opacity(0.34), radius: 24, y: 14)
            .scaleEffect(result.scale)
            .rotationEffect(.degrees(result.rotation))
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { dragOffset = $0.translation }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                            dragOffset = .zero
                        }
                    }
            )
    }
}

private struct LilithVoiceResultLayer: View {
    let results: [LilithVoiceResult]

    var body: some View {
        ZStack {
            ForEach(results) { item in
                LilithVoiceBubbleView(result: item)
                    .position(item.position)
                    .zIndex(Double(item.scale))
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
}

private struct LilithVoiceMetalVoidView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.clearColor = MTLClearColorMake(0, 0, 0, 1)
        view.isPaused = false
        view.enableSetNeedsDisplay = false

        if let renderer = LilithVoiceMetalRenderer(view: view) {
            context.coordinator.renderer = renderer
            view.delegate = renderer
        }

        return view
    }

    func updateUIView(_ uiView: MTKView, context: Context) {}

    final class Coordinator {
        var renderer: LilithVoiceMetalRenderer?
    }
}

private final class LilithVoiceMetalRenderer: NSObject, MTKViewDelegate {
    private let commandQueue: MTLCommandQueue
    private var time: Float = 0

    init?(view: MTKView) {
        guard let device = view.device,
              let queue = device.makeCommandQueue() else {
            return nil
        }
        self.commandQueue = queue
        super.init()
    }

    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }

        time += 0.01
        let intensity = sin(time) * 0.02 + 0.02

        view.clearColor = MTLClearColorMake(
            Double(intensity),
            Double(intensity * 0.35),
            Double(intensity * 0.55),
            1
        )

        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
}

struct LilithVoiceConsoleView: View {
    @EnvironmentObject private var speech: LilithSpeechManager
    @EnvironmentObject private var stateManager: LilithStateManager

    @StateObject private var viewModel = LilithVoiceConsoleViewModel()
    @State private var input = ""
    @State private var showRealtime = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LilithVoiceMetalVoidView()
                    .ignoresSafeArea()

                LilithVoiceResultLayer(results: viewModel.results)

                VStack(spacing: 18) {
                    HStack {
                        Spacer()

                        Button {
                            showRealtime = true
                        } label: {
                            Image(systemName: "bolt.horizontal.circle.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.white.opacity(0.12), in: Circle())
                        }
                    }
                    .padding(.horizontal, 18)

                    Text(timeString)
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.top, 8)

                    LilithView()
                        .frame(maxWidth: 220, maxHeight: 220)

                    Text(statusText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.08), in: Capsule())

                    Spacer()

                    HStack(spacing: 12) {
                        TextField("Ask Lilith anything...", text: $input)
                            .textInputAutocapitalization(.sentences)
                            .disableAutocorrection(false)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                            .onSubmit {
                                submit(using: geo.size)
                            }

                        Button {
                            toggleListening()
                        } label: {
                            Image(systemName: speech.isListening ? "waveform.circle.fill" : "mic.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(.white.opacity(0.12), in: Circle())
                        }

                        Button {
                            submit(using: geo.size)
                        } label: {
                            Image(systemName: viewModel.isLoading ? "hourglass" : "arrow.up")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(viewModel.isLoading ? .white.opacity(0.08) : LilithTheme.accentA.opacity(0.8), in: Circle())
                        }
                        .disabled(viewModel.isLoading)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear {
            stateManager.set(.idle)
        }
        .onChange(of: speech.transcript) { _, newValue in
            if speech.isListening {
                input = newValue
            }
        }
        .onChange(of: speech.speaking) { _, speaking in
            if !speaking && !speech.isListening && !viewModel.isLoading {
                stateManager.set(.idle)
            }
        }
        .sheet(isPresented: $showRealtime) {
            RealtimeVoidView()
        }
    }

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"
        return formatter.string(from: Date())
    }

    private var statusText: String {
        if speech.isListening {
            return "Listening for your voice..."
        }
        if viewModel.isLoading {
            return "Lilith is thinking..."
        }
        if speech.speaking {
            return "Lilith is speaking."
        }
        if viewModel.conversationId != nil {
            return "Voice session active."
        }
        return "Speak or type a command for Lilith."
    }

    private func toggleListening() {
        if speech.isListening {
            speech.stopListening()
            input = speech.transcript
            stateManager.set(.interacting)
            return
        }

        Task {
            await speech.requestPermissions()
            await MainActor.run {
                stateManager.set(.listening)
                speech.startListening()
            }
        }
    }

    private func submit(using size: CGSize) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if speech.isListening {
            speech.stopListening()
        }
        let outbound = trimmed
        input = ""
        viewModel.submit(
            text: outbound,
            size: size,
            speech: speech,
            stateManager: stateManager
        )
    }
}

#Preview {
    LilithVoiceConsoleView()
        .environmentObject(LilithStateManager())
        .environmentObject(LilithSpeechManager())
}