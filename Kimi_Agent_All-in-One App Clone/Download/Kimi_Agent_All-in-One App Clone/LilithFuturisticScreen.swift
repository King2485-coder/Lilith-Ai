import SwiftUI
import CoreMotion

// MARK: - Main Screen

struct LilithFuturisticScreen: View {
    @StateObject private var motion = MotionManager()
    @State private var showLeftPanel = true
    @State private var showRightPanel = true
    @State private var isFocused = false
    @State private var selectedTool: FuturisticTool = .dashboard
    @State private var pulseCore = false
    @State private var animateSweep = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                FuturisticBackgroundLayer(
                    motionX: motion.motionX,
                    motionY: motion.motionY
                )
                .ignoresSafeArea()

                FloatingParticleLayer()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                EnergyCoreTop(
                    pulse: pulseCore,
                    motionX: motion.motionX,
                    motionY: motion.motionY
                )
                .position(
                    x: geo.size.width / 2 + motion.motionX * 10,
                    y: 82 + motion.motionY * 8
                )
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topCornerButtons
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                    TopSearchBar(
                        motionX: motion.motionX,
                        motionY: motion.motionY
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 18)

                    Spacer(minLength: 14)

                    HStack(alignment: .top, spacing: 12) {
                        if showLeftPanel && !isFocused {
                            LeftRailPanel()
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }

                        CenterWorkspacePanel(
                            selectedTool: selectedTool,
                            motionX: motion.motionX,
                            motionY: motion.motionY,
                            animateSweep: animateSweep
                        )
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                isFocused.toggle()
                                showLeftPanel = !isFocused
                                showRightPanel = !isFocused
                            }
                        }

                        if showRightPanel && !isFocused {
                            RightRailPanel(selectedTool: $selectedTool)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.horizontal, 12)

                    Spacer(minLength: 12)

                    BottomActionCluster(
                        pulseCore: pulseCore,
                        motionX: motion.motionX,
                        motionY: motion.motionY
                    )
                    .padding(.bottom, 18)

                    BottomNavBar()
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                }
            }
            .preferredColorScheme(.dark)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            if value.translation.width < -40 {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    showLeftPanel = false
                                    showRightPanel = false
                                }
                            } else if value.translation.width > 40 {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    showLeftPanel = true
                                    showRightPanel = true
                                    isFocused = false
                                }
                            }
                        }
                    }
            )
            .onAppear {
                motion.start()
                pulseCore = true
                animateSweep = true
            }
            .onDisappear {
                motion.stop()
            }
        }
    }

    private var topCornerButtons: some View {
        HStack {
            SmallCircleButton(icon: "line.3.horizontal")
            Spacer()
            SmallCircleButton(icon: "eye.slash")
        }
    }
}

// MARK: - Tools

enum FuturisticTool: String, CaseIterable {
    case dashboard
    case imageGen
    case summarize
    case videoAnalyzer
    case scanner
    case voice
    case gallery
    case pay
}

// MARK: - Motion Manager

final class MotionManager: ObservableObject {
    private let manager = CMMotionManager()
    @Published var motionX: CGFloat = 0
    @Published var motionY: CGFloat = 0

    func start() {
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 40.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let pitch = motion.attitude.pitch
            let roll = motion.attitude.roll

            self?.motionX = CGFloat(max(min(roll * 14, 12), -12))
            self?.motionY = CGFloat(max(min(pitch * 14, 12), -12))
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

// MARK: - Background

struct FuturisticBackgroundLayer: View {
    let motionX: CGFloat
    let motionY: CGFloat

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.00, green: 0.03, blue: 0.08),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ZStack {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.25),
                                    Color.clear,
                                    Color.orange.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: CGFloat(1 + i)
                        )
                        .frame(width: 520 + CGFloat(i * 130), height: 520 + CGFloat(i * 130))
                        .blur(radius: CGFloat(i))
                }
            }
            .offset(x: motionX * 1.8, y: motionY * 1.4 - 210)

            RadialGradient(
                colors: [
                    Color.cyan.opacity(0.12),
                    Color.clear
                ],
                center: .center,
                startRadius: 10,
                endRadius: 280
            )
            .offset(x: motionX * 1.5, y: motionY * 1.2 + 260)

            AngularGradient(
                colors: [
                    Color.cyan.opacity(0.12),
                    Color.orange.opacity(0.08),
                    Color.clear,
                    Color.cyan.opacity(0.08)
                ],
                center: .center
            )
            .blur(radius: 80)
            .scaleEffect(1.35)
            .offset(x: motionX, y: motionY)

            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.75)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 280)
            }
        }
    }
}

// MARK: - Particles

struct FloatingParticleLayer: View {
    private let particles = (0..<35).map { _ in Particle() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    ParticleView(particle: particle, size: geo.size)
                }
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    let x = CGFloat.random(in: 0.02...0.98)
    let y = CGFloat.random(in: 0.02...0.98)
    let size = CGFloat.random(in: 1.5...4.0)
    let opacity = Double.random(in: 0.04...0.18)
    let duration = Double.random(in: 6.0...18.0)
    let offset = CGFloat.random(in: 8...28)
    let tintBlue = Bool.random()
}

struct ParticleView: View {
    let particle: Particle
    let size: CGSize
    @State private var drift = false

    var body: some View {
        Circle()
            .fill(particle.tintBlue ? Color.cyan.opacity(particle.opacity) : Color.orange.opacity(particle.opacity))
            .frame(width: particle.size, height: particle.size)
            .blur(radius: particle.size * 0.5)
            .position(
                x: particle.x * size.width + (drift ? particle.offset : -particle.offset),
                y: particle.y * size.height + (drift ? -particle.offset : particle.offset)
            )
            .animation(.easeInOut(duration: particle.duration).repeatForever(autoreverses: true), value: drift)
            .onAppear { drift = true }
    }
}

// MARK: - Energy Core

struct EnergyCoreTop: View {
    let pulse: Bool
    let motionX: CGFloat
    let motionY: CGFloat
    @State private var rotate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            Color.cyan.opacity(0.55),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 2,
                        endRadius: 58
                    )
                )
                .frame(width: 80, height: 80)
                .blur(radius: 2)

            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .trim(from: 0.05, to: 0.82)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.8),
                                Color.clear,
                                Color.orange.opacity(0.35)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: CGFloat(1 + i), lineCap: .round)
                    )
                    .frame(width: 92 + CGFloat(i * 18), height: 92 + CGFloat(i * 18))
                    .rotationEffect(.degrees(rotate ? Double(360 - i * 70) : 0))
                    .animation(.linear(duration: Double(14 + i * 6)).repeatForever(autoreverses: false), value: rotate)
            }

            Circle()
                .stroke(Color.cyan.opacity(0.35), lineWidth: 1)
                .frame(width: pulse ? 118 : 106, height: pulse ? 118 : 106)
                .blur(radius: 4)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: pulse)
        }
        .shadow(color: .cyan.opacity(0.35), radius: 20)
        .shadow(color: .white.opacity(0.2), radius: 10)
        .onAppear { rotate = true }
        .offset(x: motionX * 0.6, y: motionY * 0.4)
    }
}

// MARK: - Top Bar

struct TopSearchBar: View {
    let motionX: CGFloat
    let motionY: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.black.opacity(0.45))
                .overlay(
                    Circle().stroke(Color.cyan.opacity(0.8), lineWidth: 1)
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.22), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.white.opacity(0.9))
                )

            HStack(spacing: 10) {
                Circle()
                    .stroke(Color.cyan.opacity(0.7), lineWidth: 1)
                    .frame(width: 42, height: 42)
                    .overlay(
                        Text("AI")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                    )

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.white.opacity(0.75))
                    Text("Ask Lilith anything...")
                        .foregroundStyle(Color.white.opacity(0.82))
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundStyle(Color.white.opacity(0.72))
                }
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(FrostPanel(corner: 26, glow: .cyan))
            }

            HStack(spacing: 10) {
                ForEach(["wand.and.rays", "rectangle.portrait", "square.grid.2x2"], id: \.self) { icon in
                    Circle()
                        .fill(Color.black.opacity(0.45))
                        .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1))
                        .frame(width: 46, height: 46)
                        .overlay(
                            Image(systemName: icon)
                                .foregroundStyle(.white.opacity(0.82))
                        )
                }
            }
        }
        .offset(x: motionX * 0.25, y: motionY * 0.15)
    }
}

struct SmallCircleButton: View {
    let icon: String

    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.45))
            .overlay(Circle().stroke(Color.cyan.opacity(0.65), lineWidth: 1))
            .frame(width: 50, height: 50)
            .overlay(
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.88))
            )
            .shadow(color: .cyan.opacity(0.16), radius: 10)
    }
}

// MARK: - Side Panels

struct LeftRailPanel: View {
    var body: some View {
        VStack(spacing: 12) {
            FrostPanel(corner: 22, glow: .cyan) {
                VStack(alignment: .leading, spacing: 10) {
                    panelHeader("AI TOOLS")
                    toolCapsule("Image Generation", selected: true)
                    toolCapsule("Text Summarize", selected: false)
                    toolCapsule("Video Analyzer", selected: false)
                }
                .padding(14)
            }
            .frame(width: 200)

            FrostPanel(corner: 22, glow: .cyan) {
                VStack(alignment: .leading, spacing: 12) {
                    panelHeader("NOTIFICATIONS")
                    tinyInfoCard("NEWS", "METEO PROTECT: Cyberboat e les to lanch next weeklind.")
                    tinyInfoCard("Email:", "Files for the OpenAI meeting received.")
                    tinyInfoCard("Eoat", "")
                    contactList
                }
                .padding(14)
            }
            .frame(width: 200)

            FrostPanel(corner: 22, glow: .cyan) {
                VStack(alignment: .leading, spacing: 12) {
                    statRow("folder", "3,240")
                    statRow("envelope.fill", "12.7k")
                    statRow("dollarsign.circle.fill", "$4,230")
                }
                .padding(16)
            }
            .frame(width: 200)
        }
    }

    private func panelHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
            Spacer()
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(.cyan.opacity(0.9))
        }
    }

    private func toolCapsule(_ title: String, selected: Bool) -> some View {
        HStack(spacing: 10) {
            Circle()
                .stroke(Color.white.opacity(0.8), lineWidth: 1)
                .frame(width: 20, height: 20)
                .overlay(
                    Circle()
                        .fill(selected ? Color.cyan.opacity(0.9) : Color.clear)
                        .frame(width: 8, height: 8)
                )

            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.93))
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(selected ? Color.cyan.opacity(0.10) : Color.black.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(selected ? Color.cyan.opacity(0.45) : Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }

    private func tinyInfoCard(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.88))
                Spacer()
                Circle().fill(Color.white.opacity(0.3)).frame(width: 6, height: 6)
            }
            if !body.isEmpty {
                Text(body)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.68))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.black.opacity(0.16))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.10), lineWidth: 1))
        )
    }

    private var contactList: some View {
        VStack(spacing: 10) {
            ForEach(["Chloe", "Antonio", "Alex", "Hana", "Sarah"], id: \.self) { name in
                HStack {
                    Circle().fill(Color.white.opacity(0.12)).frame(width: 24, height: 24)
                        .overlay(Image(systemName: "person.fill").font(.system(size: 11)).foregroundStyle(.white.opacity(0.75)))
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                    Spacer()
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: 12, height: 4)
                }
            }
        }
    }

    private func statRow(_ icon: String, _ value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.white.opacity(0.9))
            Text(value)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
            Spacer()
        }
    }
}

struct RightRailPanel: View {
    @Binding var selectedTool: FuturisticTool

    var body: some View {
        VStack(spacing: 12) {
            FrostPanel(corner: 22, glow: .cyan) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        HStack(spacing: 8) {
                            Circle().fill(Color.cyan).frame(width: 8, height: 8)
                            Text("24,356")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Circle().stroke(Color.white.opacity(0.4), lineWidth: 1).frame(width: 28, height: 28)
                    }

                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [Color.orange.opacity(0.25), Color.cyan.opacity(0.15), Color.black.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 150)
                        .overlay(
                            VStack(alignment: .leading, spacing: 4) {
                                Spacer()
                                Text("techpulse.ai")
                                    .foregroundStyle(.white.opacity(0.95))
                                    .font(.system(size: 14, weight: .medium))
                            }
                            .padding(10),
                            alignment: .bottomLeading
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Major Tech Event Tomorrow")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("The future tech lineup are ready. AI • Space • Sci-fi architectures and more.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
                .padding(14)
            }
            .frame(width: 220)

            FrostPanel(corner: 22, glow: .cyan) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("QUICK TOOLS")
                            .foregroundStyle(.white.opacity(0.95))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 12) {
                        quickTool("Mails", "envelope.fill")
                        quickTool("Crndar", "envelope.open.fill")
                        quickTool("Firfts", "square.and.pencil")
                        quickTool("Notes", "note.text")
                        quickTool("Remindr", "bell.fill")
                        quickTool("Files", "folder.fill")
                    }
                }
                .padding(14)
            }
            .frame(width: 220)

            FrostPanel(corner: 22, glow: .cyan) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("TOOLS")
                            .foregroundStyle(.white.opacity(0.95))
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    listTool("Voice Transcription", .voice)
                    listTool("Text Summarization", .summarize)
                    listTool("Screen Analytics", .videoAnalyzer)
                    listTool("AI Vision Scanner", .scanner)
                }
                .padding(14)
            }
            .frame(width: 220)
        }
    }

    private func quickTool(_ title: String, _ icon: String) -> some View {
        VStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
                .frame(height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundStyle(.white.opacity(0.9))
                )
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.84))
        }
    }

    private func listTool(_ title: String, _ tool: FuturisticTool) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                selectedTool = tool
            }
        } label: {
            HStack {
                Circle().stroke(Color.white.opacity(0.35), lineWidth: 1).frame(width: 24, height: 24)
                    .overlay(Image(systemName: "waveform").font(.system(size: 9)).foregroundStyle(.white.opacity(0.8)))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.95))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .padding(.horizontal, 10)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.10), lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Center Workspace

struct CenterWorkspacePanel: View {
    let selectedTool: FuturisticTool
    let motionX: CGFloat
    let motionY: CGFloat
    let animateSweep: Bool
    @State private var shimmer = false

    var body: some View {
        FrostPanel(corner: 26, glow: .cyan) {
            ZStack {
                RoundedRectangle(cornerRadius: 26)
                    .fill(Color.clear)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.05), .clear],
                            startPoint: shimmer ? .leading : .trailing,
                            endPoint: shimmer ? .trailing : .leading
                        )
                        .blur(radius: 30)
                        .opacity(0.6)
                        .mask(
                            RoundedRectangle(cornerRadius: 26)
                                .fill(Color.white)
                        )
                    )

                Group {
                    switch selectedTool {
                    case .dashboard:
                        dashboardContent
                    case .imageGen:
                        toolPanel(title: "Image Generation", subtitle: "Create and preview cinematic visuals inside the live workspace.")
                    case .summarize:
                        toolPanel(title: "Text Summarization", subtitle: "Summaries, key points, and extracted insight appear here.")
                    case .videoAnalyzer:
                        toolPanel(title: "Video Analyzer", subtitle: "Frame insight, captions, and scene understanding load here.")
                    case .scanner:
                        toolPanel(title: "Scanner", subtitle: "Scan, inspect, and route visual content here.")
                    case .voice:
                        toolPanel(title: "Voice Transcription", subtitle: "Live recording, transcript flow, and action suggestions appear here.")
                    case .gallery:
                        toolPanel(title: "Gallery", subtitle: "Selected images and media open in the center display.")
                    case .pay:
                        toolPanel(title: "Payments", subtitle: "Payment actions, approvals, and wallet controls load here.")
                    }
                }
                .padding(16)
            }
        }
        .frame(maxWidth: .infinity)
        .offset(x: motionX * 0.35, y: motionY * 0.25)
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .onAppear { shimmer = true }
        .animation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true), value: shimmer)
    }

    private var dashboardContent: some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    Circle().fill(Color.white.opacity(0.14)).frame(width: 42, height: 42)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.white.opacity(0.9)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Chloe")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                        Text("Online · Day 24")
                            .foregroundStyle(.white.opacity(0.75))
                            .font(.system(size: 13))
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Text("9:43")
                        .foregroundStyle(.white.opacity(0.82))
                    Capsule().fill(Color.white.opacity(0.25)).frame(width: 20, height: 8)
                }
            }

            chatBubble("Good news!", width: 180)

            HStack {
                Spacer()
                capsuleTag("I FOLLOW")
            }

            chatBubble("Annot at the last OpenAI meeting.", width: 290)
            chatBubble("This was from The ac...", width: 220)

            RoundedRectangle(cornerRadius: 20)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.16), Color.orange.opacity(0.18), Color.black.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 280)
                .overlay(
                    VStack {
                        Spacer()
                        Text("AI is amazing!")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.bottom, 18)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )

            HStack {
                Image(systemName: "checkmark")
                Text("Sending it to you now!")
                Spacer()
                Image(systemName: "clock.arrow.circlepath")
            }
            .foregroundStyle(.white.opacity(0.94))
            .font(.system(size: 15, weight: .medium))
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(FrostPanel(corner: 18, glow: .cyan))

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("futureai.com")
                        .font(.system(size: 22, weight: .medium, design: .rounded))
                        .foregroundStyle(.white)
                    Text("This was from the last OpenAI meeting.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.72))
                }
                Spacer()
                Circle()
                    .stroke(Color.cyan.opacity(0.8), lineWidth: 1)
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "paperplane.fill").foregroundStyle(.white))
            }
            .padding(.horizontal, 18)
            .frame(height: 86)
            .background(FrostPanel(corner: 20, glow: .cyan))
        }
    }

    private func chatBubble(_ text: String, width: CGFloat) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(width: width, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.22))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.12), lineWidth: 1))
                )
            Spacer()
        }
    }

    private func capsuleTag(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text)
            Image(systemName: "chevron.right")
            Image(systemName: "arrow.clockwise")
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.cyan.opacity(0.95))
        .padding(.horizontal, 14)
        .frame(height: 36)
        .background(
            Capsule()
                .fill(Color.cyan.opacity(0.08))
                .overlay(Capsule().stroke(Color.cyan.opacity(0.35), lineWidth: 1))
        )
    }

    private func toolPanel(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.72))

            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.15), Color.orange.opacity(0.10), Color.black.opacity(0.24)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: 14) {
                        Circle()
                            .stroke(Color.cyan.opacity(0.75), lineWidth: 2)
                            .frame(width: 90, height: 90)
                            .overlay(Circle().fill(Color.cyan.opacity(0.12)).frame(width: 72, height: 72))
                        Text("Live tool surface")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

// MARK: - Bottom Cluster

struct BottomActionCluster: View {
    let pulseCore: Bool
    let motionX: CGFloat
    let motionY: CGFloat
    @State private var rotateBlue = false
    @State private var rotateOrange = false
    @State private var sendHalo = false

    var body: some View {
        ZStack {
            HStack {
                SmallBottomIcon(icon: "camera")
                    .offset(x: -118, y: -34)

                SmallBottomIcon(icon: "waveform")
                    .offset(x: -84, y: -34)

                Spacer()

                SmallBottomIcon(icon: "photo")
                    .offset(x: 84, y: -34)

                SmallBottomIcon(icon: "phone")
                    .offset(x: 118, y: -34)
            }
            .frame(width: 360)

            HStack(alignment: .center, spacing: 32) {
                SecondaryCoreButton(
                    title: "SCAN",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .cyan,
                    rotate: rotateBlue
                )
                .offset(y: 20)

                PrimarySendCore(
                    pulse: pulseCore,
                    halo: sendHalo
                )

                SecondaryCoreButton(
                    title: "PAY",
                    systemImage: "creditcard.fill",
                    tint: .orange,
                    rotate: rotateOrange
                )
                .offset(y: 20)
            }

            PageDots()
                .offset(y: 92)
        }
        .offset(x: motionX * 0.14, y: motionY * 0.12)
        .onAppear {
            rotateBlue = true
            rotateOrange = true
            sendHalo = true
        }
    }
}

struct SmallBottomIcon: View {
    let icon: String
    @State private var flicker = false

    var body: some View {
        Circle()
            .fill(Color.black.opacity(0.45))
            .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
            .frame(width: 42, height: 42)
            .overlay(
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.88))
            )
            .shadow(color: Color.cyan.opacity(flicker ? 0.24 : 0.08), radius: flicker ? 12 : 4)
            .onAppear { flicker = true }
            .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: flicker)
    }
}

struct SecondaryCoreButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let rotate: Bool
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.35), lineWidth: 1)
                .frame(width: pulse ? 112 : 104, height: pulse ? 112 : 104)
                .blur(radius: 6)

            Circle()
                .trim(from: 0.08, to: 0.90)
                .stroke(tint.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 98, height: 98)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: rotate)

            Circle()
                .fill(Color.black.opacity(0.55))
                .overlay(Circle().stroke(tint.opacity(0.72), lineWidth: 1.2))
                .frame(width: 90, height: 90)

            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: tint.opacity(0.28), radius: 18)
        .onAppear { pulse = true }
        .animation(.easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: pulse)
    }
}

struct PrimarySendCore: View {
    let pulse: Bool
    let halo: Bool
    @State private var rotate = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.22), lineWidth: 1)
                .frame(width: halo ? 170 : 156, height: halo ? 170 : 156)
                .blur(radius: 10)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: halo)

            Circle()
                .trim(from: 0.02, to: 0.94)
                .stroke(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.95), Color.clear, Color.cyan.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                )
                .frame(width: 150, height: 150)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 18).repeatForever(autoreverses: false), value: rotate)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.28), Color.black.opacity(0.75)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 90
                    )
                )
                .frame(width: pulse ? 138 : 134, height: pulse ? 138 : 134)
                .overlay(
                    Circle().stroke(Color.white.opacity(0.30), lineWidth: 1.2)
                )
                .shadow(color: Color.cyan.opacity(0.45), radius: 24)

            Text("SEND")
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
        .onAppear { rotate = true }
    }
}

struct PageDots: View {
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(Color.cyan).frame(width: 10, height: 10)
            Circle().stroke(Color.white.opacity(0.5), lineWidth: 1).frame(width: 10, height: 10)
            Circle().stroke(Color.white.opacity(0.5), lineWidth: 1).frame(width: 10, height: 10)
        }
    }
}

// MARK: - Bottom Nav

struct BottomNavBar: View {
    var body: some View {
        HStack {
            bottomNavItem("FUTURISTIC", "circle.grid.cross.fill", selected: true)
            Spacer()
            bottomNavItem("THE VOID", "hurricane", selected: false)
            Spacer()
            bottomNavItem("TOOLS", "square.grid.2x2", selected: false)
        }
        .padding(.horizontal, 32)
        .frame(height: 92)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.black.opacity(0.54))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func bottomNavItem(_ title: String, _ icon: String, selected: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(selected ? Color.cyan : Color.white.opacity(0.72))
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(selected ? Color.white : Color.white.opacity(0.68))
        }
    }
}

// MARK: - Shared Panel

enum GlowColor {
    case cyan
    case orange

    var color: Color {
        switch self {
        case .cyan: return .cyan
        case .orange: return .orange
        }
    }
}

struct FrostPanel<Content: View>: View {
    let corner: CGFloat
    let glow: GlowColor
    let content: Content

    init(corner: CGFloat, glow: GlowColor, @ViewBuilder content: () -> Content) {
        self.corner = corner
        self.glow = glow
        self.content = content()
    }

    // Compile-safety convenience for shell/background usage with no explicit content
    init(corner: CGFloat, glow: GlowColor) where Content == EmptyView {
        self.corner = corner
        self.glow = glow
        self.content = EmptyView()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.black.opacity(0.34))
            .background(.ultraThinMaterial.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(glow.color.opacity(0.16), lineWidth: 1)
                    .blur(radius: 6)
            )
            .overlay(content)
            .shadow(color: glow.color.opacity(0.08), radius: 12)
    }
}

// MARK: - Preview

#Preview {
    LilithFuturisticScreen()
}
