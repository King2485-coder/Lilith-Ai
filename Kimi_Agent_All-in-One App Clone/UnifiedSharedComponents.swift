import SwiftUI

enum UnifiedGlow {
    case cyan
    case orange

    var color: Color {
        switch self {
        case .cyan: return .cyan
        case .orange: return .orange
        }
    }
}

struct UnifiedFrostPanel<Content: View>: View {
    let corner: CGFloat
    let glow: UnifiedGlow
    let content: Content

    init(corner: CGFloat, glow: UnifiedGlow, @ViewBuilder content: () -> Content) {
        self.corner = corner
        self.glow = glow
        self.content = content()
    }

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(Color.black.opacity(0.34))
            .background(.ultraThinMaterial.opacity(0.14))
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(glow.color.opacity(0.14), lineWidth: 1)
                    .blur(radius: 6)
            )
            .shadow(color: glow.color.opacity(0.08), radius: 12)
            .overlay(content)
    }
}

struct UnifiedParticleLayer: View {
    private let particles = (0..<34).map { _ in UnifiedParticle() }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    UnifiedParticleView(particle: particle, size: geo.size)
                }
            }
        }
    }
}

struct UnifiedParticle: Identifiable {
    let id = UUID()
    let x = CGFloat.random(in: 0.02...0.98)
    let y = CGFloat.random(in: 0.02...0.98)
    let size = CGFloat.random(in: 1.4...3.8)
    let opacity = Double.random(in: 0.04...0.16)
    let duration = Double.random(in: 6.0...18.0)
    let offset = CGFloat.random(in: 8...26)
    let tintBlue = Bool.random()
}

struct UnifiedParticleView: View {
    let particle: UnifiedParticle
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

struct UnifiedBottomNav: View {
    let selected: LilithUnifiedScreen

    var body: some View {
        HStack {
            navItem("FUTURISTIC", "circle.grid.cross.fill", selected == .futuristic)
            Spacer()
            navItem("THE VOID", "hurricane", selected == .void)
            Spacer()
            navItem("TOOLS", "square.grid.2x2", selected == .tools)
        }
        .padding(.horizontal, 30)
        .frame(height: 92)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(Color.black.opacity(0.52))
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func navItem(_ title: String, _ icon: String, _ selected: Bool) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 26))
                .foregroundStyle(selected ? Color.cyan : Color.white.opacity(0.72))
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(selected ? .white : .white.opacity(0.66))
        }
    }
}
