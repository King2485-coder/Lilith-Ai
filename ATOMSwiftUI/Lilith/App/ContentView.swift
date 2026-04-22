import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var speech: LilithSpeechManager
    @EnvironmentObject private var state: LilithStateManager

    var body: some View {
        LilithRootSystem()
    }
}

private struct ObsidianFluidBackground: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { _ in
            Canvas { context, size in
                phase += 0.003

                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(rect), with: .color(Color.black))

                let silver1 = Color(red: 0.22, green: 0.22, blue: 0.24).opacity(0.34)
                let silver2 = Color(red: 0.43, green: 0.43, blue: 0.46).opacity(0.16)
                let silver3 = Color(red: 0.12, green: 0.12, blue: 0.13).opacity(0.54)

                for idx in 0 ..< 4 {
                    var blob = Path()
                    let w = size.width * (0.82 + CGFloat(idx) * 0.08)
                    let h = size.height * (0.56 + CGFloat(idx) * 0.09)
                    let x = (size.width - w) * 0.5 + sin(phase * 4 + CGFloat(idx)) * 28
                    let y = (size.height - h) * 0.5 + cos(phase * 5 + CGFloat(idx) * 0.7) * 22
                    blob.addEllipse(in: CGRect(x: x, y: y, width: w, height: h))

                    let shade: Color = idx % 3 == 0 ? silver1 : (idx % 3 == 1 ? silver2 : silver3)
                    context.fill(blob, with: .color(shade), style: FillStyle(eoFill: false, antialiased: true))
                }
            }
            .blur(radius: 36)
        }
        .overlay(
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.clear, Color.black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct VoidInputDock: View {
    @Binding var text: String
    var isListening: Bool
    var onSend: () -> Void
    var onVoice: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField("Ask Lilith anything...", text: $text)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .foregroundStyle(Color.white.opacity(0.92))
                .font(.system(size: 16, weight: .medium, design: .rounded))

            Button(action: onVoice) {
                Image(systemName: isListening ? "waveform.circle.fill" : "mic.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isListening ? Color(red: 0.70, green: 0.72, blue: 0.78) : Color.white.opacity(0.86))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.05), in: Circle())
            }
            .buttonStyle(.plain)

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.07), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.07, green: 0.07, blue: 0.08).opacity(0.86))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
                .shadow(color: Color.white.opacity(0.08), radius: 16, y: 2)
        )
    }
}

private enum VoidPanelKind {
    case text
    case image
    case video
    case tool
    case suggestion
}

private struct VoidPanel: Identifiable {
    let id = UUID()
    let title: String
    let content: String
    let kind: VoidPanelKind
    let position: CGPoint
}

private struct VoidFloatingPanel: View {
    let panel: VoidPanel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(panel.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.55))
            Text(panel.content)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.88))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.08, green: 0.08, blue: 0.09).opacity(0.58))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.09), lineWidth: 1)
                )
                .shadow(color: Color.white.opacity(0.06), radius: 14, y: 1)
        )
    }
}

private struct MainBodyHUDBackground: View {
    var body: some View {
        ZStack {
            Color.black

            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.05, blue: 0.09),
                    Color(red: 0.03, green: 0.03, blue: 0.04),
                    Color(red: 0.08, green: 0.04, blue: 0.01)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(red: 0.16, green: 0.48, blue: 0.88).opacity(0.16), lineWidth: 1)
                .blendMode(.screen)

            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(red: 0.93, green: 0.45, blue: 0.13).opacity(0.12), lineWidth: 1)
                .padding(6)
        }
        .ignoresSafeArea()
    }
}

private struct MainBodyFeatureRail: View {
    let title: String
    let sections: [MainBodyMenuSection]
    @Binding var selectedFeature: String
    var onSelect: (String) -> Void

    @State private var expandedSectionIDs: Set<String>

    init(title: String, sections: [MainBodyMenuSection], selectedFeature: Binding<String>, onSelect: @escaping (String) -> Void) {
        self.title = title
        self.sections = sections
        self._selectedFeature = selectedFeature
        self.onSelect = onSelect
        self._expandedSectionIDs = State(initialValue: Set(sections.map { $0.id }))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.16, green: 0.52, blue: 0.95).opacity(0.92))

            ScrollView(showsIndicators: true) {
                VStack(spacing: 8) {
                    ForEach(sections) { section in
                        sectionView(section)
                    }
                }
                .padding(.trailing, 2)
            }
        }
    }

    private func sectionView(_ section: MainBodyMenuSection) -> some View {
        VStack(spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    if expandedSectionIDs.contains(section.id) {
                        expandedSectionIDs.remove(section.id)
                    } else {
                        expandedSectionIDs.insert(section.id)
                    }
                }
            } label: {
                HStack {
                    Text(section.title)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                    Image(systemName: expandedSectionIDs.contains(section.id) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            if expandedSectionIDs.contains(section.id) {
                VStack(spacing: 6) {
                    ForEach(section.items, id: \.self) { item in
                        featureButton(item)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func featureButton(_ feature: String) -> some View {
        Button {
            onSelect(feature)
        } label: {
            Text(feature)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.44))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke((selectedFeature == feature ? Color(red: 0.15, green: 0.52, blue: 0.95) : Color.white.opacity(0.08)), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

private struct MainBodyChatCore: View {
    let log: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LILITH MAIN BODY")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 0.16, green: 0.52, blue: 0.95).opacity(0.95))

            Text("Chat / interaction panel")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(log.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color.black.opacity(0.30), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.42))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color(red: 0.16, green: 0.52, blue: 0.95).opacity(0.44), lineWidth: 1)
                )
        )
    }
}

private struct MainBodyMenuSection: Identifiable {
    let id: String
    let title: String
    let items: [String]
}

private enum MainBodyFeatureCatalog {
    static let leftSections: [MainBodyMenuSection] = [
        MainBodyMenuSection(
            id: "core-ai",
            title: "Core AI",
            items: ["Image generation", "Text summarize", "Video analyzer", "Realtime voice"]
        ),
        MainBodyMenuSection(
            id: "communications",
            title: "Communications",
            items: ["Secure messages", "Voice calls", "Presence monitor", "System inbox"]
        ),
        MainBodyMenuSection(
            id: "lte-stack",
            title: "LTE Package (Imported)",
            items: ["Open5GS control", "srsRAN eNodeB", "eSIM generator", "LTE VoIP bridge", "MITM test harness"]
        ),
        MainBodyMenuSection(
            id: "linux-operator",
            title: "Linux Operator (Imported)",
            items: ["Machine connection", "Terminal session", "System monitoring", "File manager", "Password recovery"]
        )
    ]

    static let rightSections: [MainBodyMenuSection] = [
        MainBodyMenuSection(
            id: "live-feeds",
            title: "Live Cards",
            items: ["News", "Events", "Content preview"]
        ),
        MainBodyMenuSection(
            id: "finance",
            title: "Finance",
            items: ["Wealth Wizard", "Approvals", "Transfer simulation", "Invoice generator"]
        ),
        MainBodyMenuSection(
            id: "automation",
            title: "Automation",
            items: ["Workflow builder", "Web clone", "Document tools", "Memory controls"]
        )
    ]
}

private struct MainBodyActionCluster: View {
    var body: some View {
        HStack(spacing: 26) {
            actionCircle(label: "SCAN", color: Color(red: 0.15, green: 0.52, blue: 0.95), diameter: 68)
            actionCircle(label: "SEND", color: Color(red: 0.95, green: 0.52, blue: 0.18), diameter: 96)
            actionCircle(label: "PAY", color: Color(red: 0.15, green: 0.52, blue: 0.95), diameter: 68)
        }
        .frame(maxWidth: .infinity)
    }

    private func actionCircle(label: String, color: Color, diameter: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.56))
                .overlay(Circle().stroke(color.opacity(0.64), lineWidth: 1.2))
                .shadow(color: color.opacity(0.36), radius: 14, y: 0)
            Text(label)
                .font(.system(size: diameter > 80 ? 18 : 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: diameter, height: diameter)
    }
}

private struct MainBodyToolsGrid: View {
    private let symbols = [
        "wand.and.stars", "camera.viewfinder", "qrcode.viewfinder", "waveform",
        "creditcard", "photo", "video", "globe"
    ]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(0 ..< 2) { row in
                HStack(spacing: 8) {
                    ForEach(0 ..< 4) { col in
                        let index = row * 4 + col
                        Image(systemName: symbols[index])
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.92))
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.black.opacity(0.46))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.white.opacity(0.13), lineWidth: 1)
                                    )
                            )
                    }
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.50))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(LilithStateManager())
        .environmentObject(LilithSpeechManager())
}

