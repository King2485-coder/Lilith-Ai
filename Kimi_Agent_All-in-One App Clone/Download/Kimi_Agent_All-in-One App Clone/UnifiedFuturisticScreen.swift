import SwiftUI

struct UnifiedFuturisticScreen: View {
    @ObservedObject var appState: LilithUnifiedAppState
    @StateObject private var motion = UnifiedMotionManager()

    @State private var pulseCore = false
    @State private var rotateTopRings = false
    @State private var shimmer = false
    @State private var sendHalo = false
    @State private var scanRotate = false
    @State private var payRotate = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                futuristicBackground
                    .ignoresSafeArea()

                UnifiedParticleLayer()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                topEnergyCore
                    .position(
                        x: geo.size.width / 2 + motion.motionX * 9,
                        y: 88 + motion.motionY * 8
                    )
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 18)
                        .padding(.top, 14)

                    searchBar
                        .padding(.horizontal, 14)
                        .padding(.top, 22)

                    Spacer(minLength: 14)

                    HStack(alignment: .top, spacing: 12) {
                        if appState.showLeftPanel && !appState.focusMode {
                            futuristicLeftPanel
                                .frame(width: 190)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }

                        futuristicCenterWorkspace
                            .frame(maxWidth: .infinity)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    appState.focusMode.toggle()
                                    appState.showLeftPanel = !appState.focusMode
                                    appState.showRightPanel = !appState.focusMode
                                }
                            }

                        if appState.showRightPanel && !appState.focusMode {
                            futuristicRightPanel
                                .frame(width: 215)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        }
                    }
                    .padding(.horizontal, 12)
                    .animation(.easeInOut(duration: 0.28), value: appState.showLeftPanel)
                    .animation(.easeInOut(duration: 0.28), value: appState.showRightPanel)
                    .animation(.easeInOut(duration: 0.28), value: appState.focusMode)

                    Spacer(minLength: 10)

                    bottomActionCluster
                        .padding(.bottom, 18)

                    UnifiedBottomNav(selected: .futuristic)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 10)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 18)
                    .onEnded { value in
                        if abs(value.translation.width) > abs(value.translation.height) {
                            if value.translation.width < -40 {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    appState.showLeftPanel = false
                                    appState.showRightPanel = false
                                    appState.focusMode = true
                                }
                            } else if value.translation.width > 40 {
                                withAnimation(.easeInOut(duration: 0.28)) {
                                    appState.showLeftPanel = true
                                    appState.showRightPanel = true
                                    appState.focusMode = false
                                }
                            }
                        }
                    }
            )
            .onAppear {
                motion.start()
                pulseCore = true
                rotateTopRings = true
                shimmer = true
                sendHalo = true
                scanRotate = true
                payRotate = true
            }
            .onDisappear {
                motion.stop()
            }
        }
    }

    private var futuristicBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.01, green: 0.03, blue: 0.08),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            ForEach(0..<4, id: \.self) { i in
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.24),
                                Color.clear,
                                Color.orange.opacity(0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: CGFloat(i + 1)
                    )
                    .frame(width: 420 + CGFloat(i * 120), height: 420 + CGFloat(i * 120))
                    .blur(radius: CGFloat(i))
                    .offset(
                        x: motion.motionX * CGFloat(1.4 + Double(i) * 0.15),
                        y: -240 + motion.motionY * CGFloat(1.1 + Double(i) * 0.12)
                    )
            }

            RadialGradient(
                colors: [Color.cyan.opacity(0.10), Color.clear],
                center: .center,
                startRadius: 8,
                endRadius: 260
            )
            .offset(x: motion.motionX * 1.4, y: 240 + motion.motionY * 0.8)

            AngularGradient(
                colors: [
                    Color.cyan.opacity(0.10),
                    Color.orange.opacity(0.08),
                    Color.clear,
                    Color.cyan.opacity(0.05)
                ],
                center: .center
            )
            .blur(radius: 90)
            .scaleEffect(1.35)

            VStack {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 240)
            }
        }
    }

    private var topEnergyCore: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.9),
                            Color.cyan.opacity(0.48),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 48
                    )
                )
                .frame(width: 70, height: 70)
                .blur(radius: 2)

            Circle()
                .trim(from: 0.08, to: 0.92)
                .stroke(Color.cyan.opacity(0.75), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 94, height: 94)
                .rotationEffect(.degrees(rotateTopRings ? 360 : 0))
                .animation(.linear(duration: 16).repeatForever(autoreverses: false), value: rotateTopRings)

            Circle()
                .stroke(Color.cyan.opacity(0.22), lineWidth: 1)
                .frame(width: pulseCore ? 110 : 100, height: pulseCore ? 110 : 100)
                .blur(radius: 5)
                .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: pulseCore)
        }
        .shadow(color: .cyan.opacity(0.24), radius: 18)
    }

    private var topBar: some View {
        HStack {
            Text("3:39")
                .foregroundStyle(.white)
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Spacer()

            HStack(spacing: 8) {
                topCircleIcon("line.3.horizontal") {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        appState.showLeftPanel.toggle()
                    }
                }

                topCircleIcon(appState.focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        appState.focusMode.toggle()
                        appState.showLeftPanel = !appState.focusMode
                        appState.showRightPanel = !appState.focusMode
                    }
                }

                topCircleIcon("sidebar.right") {
                    withAnimation(.easeInOut(duration: 0.24)) {
                        appState.showRightPanel.toggle()
                    }
                }
            }
        }
    }

    private func topCircleIcon(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(Color.black.opacity(0.40))
                .overlay(Circle().stroke(Color.cyan.opacity(0.6), lineWidth: 1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: icon)
                        .foregroundStyle(.white.opacity(0.9))
                )
        }
        .buttonStyle(.plain)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.black.opacity(0.45))
                .overlay(Circle().stroke(Color.cyan.opacity(0.8), lineWidth: 1))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white.opacity(0.9))
                )

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.75))

                Text("Selected tool: \(appState.selectedTool.rawValue)")
                    .foregroundStyle(.white.opacity(0.86))
                    .font(.system(size: 15, weight: .regular, design: .rounded))

                Spacer()

                Image(systemName: "sparkles")
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(UnifiedFrostPanel(corner: 26, glow: .cyan) { EmptyView() })
        }
    }

    private var futuristicLeftPanel: some View {
        VStack(spacing: 12) {
            UnifiedFrostPanel(corner: 22, glow: .cyan) {
                VStack(alignment: .leading, spacing: 10) {
                    header("AI TOOLS")
                    smallRow("Image Generation")
                    smallRow("Summarize")
                    smallRow("Video Analyzer")
                }
                .padding(14)
            }

            UnifiedFrostPanel(corner: 22, glow: .cyan) {
                VStack(alignment: .leading, spacing: 10) {
                    header("STATUS")
                    dotRow("Today plan synchronized")
                    dotRow("Memory active")
                    dotRow("Context engine online")
                }
                .padding(14)
            }
        }
    }

    private var futuristicRightPanel: some View {
        VStack(spacing: 12) {
            UnifiedFrostPanel(corner: 22, glow: .cyan) {
                VStack(alignment: .leading, spacing: 10) {
                    header("TOOLS")
                    ForEach(UnifiedLilithTool.allCases.filter { $0 != .dashboard }, id: \.self) { tool in
                        Button {
                            withAnimation(.easeInOut(duration: 0.24)) {
                                appState.selectedTool = tool
                            }
                        } label: {
                            HStack {
                                Image(systemName: tool.icon)
                                    .foregroundStyle(tool.tint)
                                Text(tool.rawValue)
                                    .foregroundStyle(.white.opacity(0.93))
                                    .font(.system(size: 13, weight: .medium))
                                Spacer()
                                if appState.selectedTool == tool {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.cyan)
                                }
                            }
                            .padding(.horizontal, 10)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.18))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
        }
    }

    private var futuristicCenterWorkspace: some View {
        UnifiedFrostPanel(corner: 28, glow: .cyan) {
            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.clear)
                    .overlay(
                        LinearGradient(
                            colors: [.clear, Color.white.opacity(0.05), .clear],
                            startPoint: shimmer ? .leading : .trailing,
                            endPoint: shimmer ? .trailing : .leading
                        )
                        .blur(radius: 26)
                    )

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(appState.selectedTool == .dashboard ? "Futuristic Workspace" : appState.selectedTool.rawValue)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("Live")
                            .foregroundStyle(.cyan)
                            .font(.system(size: 13, weight: .medium))
                    }

                    Group {
                        switch appState.selectedTool {
                        case .dashboard:
                            animatedDashboardView
                        default:
                            animatedToolSurfaceView
                        }
                    }

                    Spacer()
                }
                .padding(18)
            }
        }
        .shadow(color: .cyan.opacity(0.10), radius: 18)
    }

    private var animatedDashboardView: some View {
        VStack(spacing: 12) {
            bubble("Good news!", width: 170)
            bubble("Whatever tool you choose on the Tools page appears here in the futuristic workspace.", width: 330)

            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.16), Color.orange.opacity(0.10), Color.black.opacity(0.28)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 280)
                .overlay(
                    VStack {
                        Spacer()
                        Text("AI is amazing!")
                            .foregroundStyle(.white)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .padding(.bottom, 18)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )

            HStack {
                Image(systemName: "checkmark")
                Text("Workspace synchronized")
                Spacer()
                Image(systemName: "waveform.path.ecg")
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(UnifiedFrostPanel(corner: 18, glow: .cyan) { EmptyView() })
        }
    }

    private var animatedToolSurfaceView: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("The selected tool is hosted inside this screen.")
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.76))

            RoundedRectangle(cornerRadius: 24)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.14), Color.orange.opacity(0.10), Color.black.opacity(0.26)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: 16) {
                        Circle()
                            .stroke(appState.selectedTool.tint.opacity(0.85), lineWidth: 2)
                            .frame(width: 88, height: 88)
                            .overlay(
                                Image(systemName: appState.selectedTool.icon)
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundStyle(.white)
                            )

                        Text(appState.selectedTool.rawValue)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text("This module is now active in the Futuristic layer.")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                )
                .frame(height: 360)
        }
    }

    private var bottomActionCluster: some View {
        ZStack {
            HStack {
                smallBottomIcon("camera")
                    .offset(x: -104, y: -30)

                smallBottomIcon("waveform")
                    .offset(x: -72, y: -30)

                Spacer()

                smallBottomIcon("photo")
                    .offset(x: 72, y: -30)

                smallBottomIcon("phone")
                    .offset(x: 104, y: -30)
            }
            .frame(width: 340)

            HStack(spacing: 30) {
                secondaryCore(title: "SCAN", icon: "viewfinder", tint: .cyan, rotate: scanRotate)
                primarySendCore
                secondaryCore(title: "PAY", icon: "creditcard.fill", tint: .orange, rotate: payRotate)
            }
        }
    }

    private func secondaryCore(title: String, icon: String, tint: Color, rotate: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.32), lineWidth: 1)
                .frame(width: 106, height: 106)
                .blur(radius: 6)

            Circle()
                .trim(from: 0.08, to: 0.90)
                .stroke(tint.opacity(0.76), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 98, height: 98)
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 12).repeatForever(autoreverses: false), value: rotate)

            Circle()
                .fill(Color.black.opacity(0.56))
                .overlay(Circle().stroke(tint.opacity(0.72), lineWidth: 1.2))
                .frame(width: 90, height: 90)

            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.white)
                Text(title)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .shadow(color: tint.opacity(0.22), radius: 14)
    }

    private var primarySendCore: some View {
        ZStack {
            Circle()
                .stroke(Color.cyan.opacity(0.24), lineWidth: 1)
                .frame(width: sendHalo ? 166 : 154, height: sendHalo ? 166 : 154)
                .blur(radius: 10)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: sendHalo)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.cyan.opacity(0.25), Color.black.opacity(0.72)],
                        center: .center,
                        startRadius: 10,
                        endRadius: 80
                    )
                )
                .frame(width: 138, height: 138)
                .overlay(Circle().stroke(Color.white.opacity(0.28), lineWidth: 1.2))
                .shadow(color: Color.cyan.opacity(0.34), radius: 18)

            Text("SEND")
                .font(.system(size: 30, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private func smallBottomIcon(_ icon: String) -> some View {
        Circle()
            .fill(Color.black.opacity(0.44))
            .overlay(Circle().stroke(Color.white.opacity(0.20), lineWidth: 1))
            .frame(width: 40, height: 40)
            .overlay(
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.88))
            )
    }

    private func header(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
            Spacer()
            Image(systemName: "arrow.clockwise")
                .foregroundStyle(.cyan.opacity(0.9))
        }
    }

    private func smallRow(_ text: String) -> some View {
        HStack {
            Circle()
                .stroke(Color.white.opacity(0.38), lineWidth: 1)
                .frame(width: 18, height: 18)
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            Spacer()
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }

    private func dotRow(_ text: String) -> some View {
        HStack {
            Circle()
                .fill(Color.cyan.opacity(0.8))
                .frame(width: 7, height: 7)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.84))
            Spacer()
        }
    }

    private func bubble(_ text: String, width: CGFloat) -> some View {
        HStack {
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(width: width, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.black.opacity(0.20))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                )
            Spacer()
        }
    }
}
