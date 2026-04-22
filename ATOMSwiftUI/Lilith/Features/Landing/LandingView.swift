import SwiftUI

struct LandingView: View {
    @State private var showingLogin = false
    @State private var showingRegister = false
    @State private var showingVoiceDemo = false

    private let features: [LandingFeature] = [
        .init(title: "Instant Help", subtitle: "Type or speak and Lilith answers in plain language.", icon: "sparkles"),
        .init(title: "Secure Communication", subtitle: "Message, call, and connect through Lilith IDs without centering the experience on phone numbers.", icon: "lock.bubble.right"),
        .init(title: "Tools Hub", subtitle: "Wealth Wizard, Legal Ease, code, images, video, and web workflows live inside Lilith.", icon: "square.grid.2x2"),
        .init(title: "Social Layer", subtitle: "Profiles, stories, and a clean feed are built into the same app shell.", icon: "person.2.wave.2")
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    hero
                    reassuranceRow
                    actionButtons
                    featureList
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(background)
            .navigationDestination(isPresented: $showingLogin) {
                LoginView()
            }
            .navigationDestination(isPresented: $showingRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showingVoiceDemo) {
                NavigationStack {
                    LilithVoiceConsoleView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    showingVoiceDemo = false
                                }
                            }
                        }
                }
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                LilithView()
                VStack(alignment: .leading, spacing: 6) {
                    Text("Lilith")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Your AI assistant, secure communication layer, and tools hub.")
                        .font(.callout)
                        .foregroundStyle(LilithTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Start something brilliant.")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("Lilith keeps the interface calm while combining chat, secure messaging, calls, social identity, and power tools in one place.")
                    .font(.body)
                    .foregroundStyle(LilithTheme.textSecondary)
            }
            .padding(.top, 6)
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LilithTheme.surface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(LilithTheme.border, lineWidth: 1)
                        .shadow(color: LilithTheme.accentA.opacity(0.14), radius: 12, y: 6)
                )
        )
    }

    private var reassuranceRow: some View {
        HStack(spacing: 14) {
            stat(value: "Safe", label: "Privacy-first")
            stat(value: "Fast", label: "Optimized GPUs")
            stat(value: "Ready", label: "24/7 uptime")
        }
        .padding(.horizontal, 6)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                showingRegister = true
            } label: {
                Text("Get Started")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())

            Button {
                showingLogin = true
            } label: {
                Text("I already have an account")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(.white)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(.white.opacity(0.08))
            )

            Button {
                showingVoiceDemo = true
            } label: {
                Text("Try Voice Demo")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(.white)
            .background(LilithTheme.accentA.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LilithTheme.accentA.opacity(0.35))
            )
        }
    }

    private var featureList: some View {
        VStack(spacing: 14) {
            ForEach(features) { feature in
                GlassCard {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(LilithTheme.accentA.opacity(0.14))
                                .frame(width: 46, height: 46)
                            Image(systemName: feature.icon)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(LilithTheme.accentA)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text(feature.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text(feature.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(LilithTheme.textSecondary)
                            .opacity(0.5)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(LilithTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    LilithTheme.background,
                    Color(red: 0.05, green: 0.06, blue: 0.11)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LilithTheme.glowGradient
                .opacity(0.9)
        }
        .ignoresSafeArea()
    }
}

private struct LandingFeature: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
}
