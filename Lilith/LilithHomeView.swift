import SwiftUI

// MARK: - Lilith Home View
// The primary interface. Circular HUD shell over the void.
// Left/right drawers, top search, bottom action bar.
// Everything happens inside the void. No page transitions.

struct LilithHomeView: View {
    @EnvironmentObject private var authStore: AuthStore
    @EnvironmentObject private var speech: LilithSpeechManager

    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var voidCanvasViewModel = VoidCanvasViewModel()

    @State private var selectedAgent: AgentKind = .nova
    @State private var selectedMode: AgentMode = .e1
    @State private var ultraThinking = true
    @State private var conversationID: String?
    @State private var previousMessageCount = 0
    @State private var previousResultID: UUID? = nil

    // Drawer states
    @State private var showLeftDrawer = false
    @State private var showRightDrawer = false

    // Bottom sheet for tools (alternative to drawers on compact screens)
    @State private var showToolSheet = false
    @State private var showScanAlert = false

    var body: some View {
        ZStack {
            // Layer 0: The void (pure black + 10 dots)
            Color.black.ignoresSafeArea()
            VoidCoreView().allowsHitTesting(false)

            // Layer 1: Circular HUD frame (decorative arcs)
            CircularHUDFrame()
                .allowsHitTesting(false)

            // Layer 2: Floating results and tools (the void objects)
            floatingLayer

            // Layer 3: Center content area (chat stream when active)
            centerContentLayer

            // Layer 4: Top bar
            topBar
                .zIndex(50)

            // Layer 5: Bottom action bar
            bottomActionBar
                .zIndex(50)

            // Layer 6: Left drawer
            leftDrawerOverlay
                .zIndex(100)

            // Layer 7: Right drawer
            rightDrawerOverlay
                .zIndex(100)
        }
        .onAppear {
            previousMessageCount = chatViewModel.messages.count
            previousResultID = chatViewModel.activeResult?.id
        }
        .onChange(of: chatViewModel.messages.count) { newCount in
            let oldCount = previousMessageCount
            previousMessageCount = newCount
            guard newCount > oldCount else { return }
            let newMessages = chatViewModel.messages.suffix(newCount - oldCount)
            for message in newMessages where message.role == .assistant {
                voidCanvasViewModel.spawnText(message.content)
            }
        }
        .onChange(of: chatViewModel.activeResult) { newResult in
            guard let result = newResult else {
                previousResultID = nil
                return
            }
            guard result.id != previousResultID else { return }
            previousResultID = result.id
            if result.status == .complete {
                voidCanvasViewModel.spawnResult(result)
            }
        }
        .sheet(isPresented: $showToolSheet) {
            ToolLayerView(
                onSelectDestination: { destination in
                    showToolSheet = false
                    voidCanvasViewModel.spawnTool(destination)
                },
                onInjectPrompt: { prompt in
                    showToolSheet = false
                    chatViewModel.draft = prompt
                }
            )
        }
        .alert("Scanner", isPresented: $showScanAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("QR scanner coming soon.")
        }
    }

    // MARK: - Floating Layer

    private var floatingLayer: some View {
        ZStack {
            ForEach(voidCanvasViewModel.floatingObjects) { object in
                FloatingObjectView(
                    object: object,
                    onDismiss: { voidCanvasViewModel.dismissObject(id: object.id) },
                    onBringToFront: { voidCanvasViewModel.bringToFront(id: object.id) },
                    onUpdatePosition: { voidCanvasViewModel.updatePosition(id: object.id, to: $0) },
                    onUpdateSize: { voidCanvasViewModel.updateSize(id: object.id, to: $0) },
                    onToggleExpanded: { voidCanvasViewModel.toggleExpanded(id: object.id) }
                )
            }
            ForEach(voidCanvasViewModel.floatingTools) { tool in
                FloatingToolView(
                    tool: tool,
                    onDismiss: { voidCanvasViewModel.dismissTool(id: tool.id) },
                    onBringToFront: { voidCanvasViewModel.bringToFront(id: tool.id) },
                    onUpdatePosition: { voidCanvasViewModel.updatePosition(id: tool.id, to: $0) },
                    onUpdateSize: { voidCanvasViewModel.updateSize(id: tool.id, to: $0) },
                    onToggleExpanded: { voidCanvasViewModel.toggleExpanded(id: tool.id) },
                    onSpawnResult: { voidCanvasViewModel.spawnResult($0) },
                    onLoadConversation: { cid in
                        Task {
                            guard let token = authStore.token else { return }
                            await chatViewModel.loadConversation(id: cid, token: token)
                            for msg in chatViewModel.messages where msg.role == .assistant {
                                voidCanvasViewModel.spawnText(msg.content)
                            }
                        }
                    }
                )
            }
        }
    }

    // MARK: - Center Content

    private var centerContentLayer: some View {
        GeometryReader { geo in
            Color.clear
                .onAppear {
                    let frame = geo.frame(in: .global)
                    voidCanvasViewModel.inputOrigin = CGPoint(
                        x: frame.midX,
                        y: frame.maxY - 100
                    )
                }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // AI Avatar
                Button(action: { showLeftDrawer = true }) {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.1))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .stroke(Color(white: 0.2).opacity(0.5), lineWidth: 0.5)
                            )
                        Text("AI")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(white: 0.7))
                    }
                }
                .buttonStyle(.plain)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(white: 0.35))

                    TextField("Ask Lilith anything…", text: $chatViewModel.draft)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color(white: 0.9))
                        .tint(Color(white: 0.5))

                    Button(action: {
                        if speech.isListening {
                            speech.stopListening()
                        } else {
                            speech.startListening()
                        }
                    }) {
                        Image(systemName: speech.isListening ? "waveform" : "mic")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(speech.isListening ? Color.red.opacity(0.8) : Color(white: 0.4))
                    }
                    .buttonStyle(.plain)

                    if !chatViewModel.draft.isEmpty {
                        Button(action: {
                            Task {
                                guard let token = authStore.token else { return }
                                await chatViewModel.sendMessage(
                                    token: token,
                                    agent: selectedAgent,
                                    mode: selectedMode,
                                    ultraThinking: ultraThinking
                                )
                            }
                        }) {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Color(white: 0.7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(Color(white: 0.06))
                        .overlay(
                            Capsule()
                                .stroke(Color(white: 0.15).opacity(0.4), lineWidth: 0.5)
                        )
                )

                // Right drawer trigger
                Button(action: { showRightDrawer = true }) {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.1))
                            .frame(width: 38, height: 38)
                            .overlay(
                                Circle()
                                    .stroke(Color(white: 0.2).opacity(0.5), lineWidth: 0.5)
                            )
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(white: 0.6))
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Spacer()
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Spacer()

            HStack(spacing: 0) {
                // Scan
                Button(action: { showScanAlert = true }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color(white: 0.08))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Circle()
                                        .stroke(Color(white: 0.18).opacity(0.5), lineWidth: 0.5)
                                )
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color(white: 0.6))
                        }
                        Text("SCAN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(white: 0.4))
                            .tracking(1.2)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Send (prominent center)
                Button(action: {
                    Task {
                        guard let token = authStore.token else { return }
                        await chatViewModel.sendMessage(
                            token: token,
                            agent: selectedAgent,
                            mode: selectedMode,
                            ultraThinking: ultraThinking
                        )
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.85))
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.white.opacity(0.15), radius: 20, x: 0, y: 0)

                        Text("SEND")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.black)
                            .tracking(1.5)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Pay
                Button(action: { voidCanvasViewModel.spawnTool(.finance) }) {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color(white: 0.08))
                                .frame(width: 56, height: 56)
                                .overlay(
                                    Circle()
                                        .stroke(Color(white: 0.18).opacity(0.5), lineWidth: 0.5)
                                )
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(Color(white: 0.6))
                        }
                        Text("PAY")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color(white: 0.4))
                            .tracking(1.2)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
    }

    // MARK: - Left Drawer

    private var leftDrawerOverlay: some View {
        ZStack {
            if showLeftDrawer {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showLeftDrawer = false }
                    .transition(.opacity)

                HStack(spacing: 0) {
                    HomeLeftDrawer(
                        onSelectTool: { dest in
                            showLeftDrawer = false
                            voidCanvasViewModel.spawnTool(dest)
                        },
                        onSelectContact: { _ in
                            showLeftDrawer = false
                        }
                    )
                    .frame(width: min(320, UIScreen.main.bounds.width * 0.8))
                    .background(
                        Color(white: 0.02)
                            .overlay(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(white: 0.08).opacity(0.3),
                                                Color.clear
                                            ],
                                            startPoint: .trailing,
                                            endPoint: .leading
                                        )
                                    )
                            )
                    )
                    .ignoresSafeArea()

                    Spacer()
                }
                .transition(.move(edge: .leading))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showLeftDrawer)
    }

    // MARK: - Right Drawer

    private var rightDrawerOverlay: some View {
        ZStack {
            if showRightDrawer {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { showRightDrawer = false }
                    .transition(.opacity)

                HStack(spacing: 0) {
                    Spacer()

                    HomeRightDrawer(
                        onSelectTool: { dest in
                            showRightDrawer = false
                            voidCanvasViewModel.spawnTool(dest)
                        },
                        onOpenVault: {
                            showRightDrawer = false
                            voidCanvasViewModel.spawnTool(.vault)
                        }
                    )
                    .frame(width: min(320, UIScreen.main.bounds.width * 0.8))
                    .background(
                        Color(white: 0.02)
                            .overlay(
                                Rectangle()
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(white: 0.08).opacity(0.3),
                                                Color.clear
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                    )
                    .ignoresSafeArea()
                }
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showRightDrawer)
    }
}

// MARK: - Circular HUD Frame

struct CircularHUDFrame: View {
    @State private var rotation: Double = 0

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let minDim = min(size.width, size.height)
            let outerRadius = minDim * 0.58
            let innerRadius = minDim * 0.52

            ZStack {
                // Outer arc (top)
                HomeArcShape(startAngle: .degrees(200), endAngle: .degrees(340))
                    .stroke(
                        Color(white: 0.18).opacity(0.25),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .position(x: size.width / 2, y: size.height * 0.15)

                // Outer arc (bottom)
                HomeArcShape(startAngle: .degrees(20), endAngle: .degrees(160))
                    .stroke(
                        Color(white: 0.18).opacity(0.25),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                    )
                    .frame(width: outerRadius * 2, height: outerRadius * 2)
                    .position(x: size.width / 2, y: size.height * 0.85)

                // Inner arc (top)
                HomeArcShape(startAngle: .degrees(210), endAngle: .degrees(330))
                    .stroke(
                        Color(white: 0.22).opacity(0.15),
                        style: StrokeStyle(lineWidth: 0.5, lineCap: .round)
                    )
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                    .position(x: size.width / 2, y: size.height * 0.15)

                // Inner arc (bottom)
                HomeArcShape(startAngle: .degrees(30), endAngle: .degrees(150))
                    .stroke(
                        Color(white: 0.22).opacity(0.15),
                        style: StrokeStyle(lineWidth: 0.5, lineCap: .round)
                    )
                    .frame(width: innerRadius * 2, height: innerRadius * 2)
                    .position(x: size.width / 2, y: size.height * 0.85)

                // Small tick marks on arcs
                ForEach(0..<12) { i in
                    let angle = Double(i) * 30.0
                    let tickRadius = outerRadius - 8
                    let x = size.width / 2 + cos(angle * .pi / 180) * tickRadius
                    let y = size.height * 0.15 + sin(angle * .pi / 180) * tickRadius

                    Circle()
                        .fill(Color(white: 0.3).opacity(0.15))
                        .frame(width: 2, height: 2)
                        .position(x: x, y: y)
                }
            }
        }
    }
}

struct HomeArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: rect.width / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return path
    }
}
