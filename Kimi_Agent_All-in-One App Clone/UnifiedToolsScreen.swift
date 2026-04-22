import SwiftUI

struct UnifiedToolsScreen: View {
    @ObservedObject var appState: LilithUnifiedAppState

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black,
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text("TOOLS")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("Select a tool")
                        .foregroundStyle(.white.opacity(0.65))
                        .font(.system(size: 14, weight: .medium))
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(UnifiedLilithTool.allCases.filter { $0 != .dashboard }) { tool in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    appState.selectedTool = tool
                                    appState.currentScreen = .futuristic
                                }
                            } label: {
                                VStack(spacing: 14) {
                                    Circle()
                                        .fill(Color.black.opacity(0.44))
                                        .overlay(
                                            Circle()
                                                .stroke(tool.tint.opacity(0.75), lineWidth: 1.2)
                                        )
                                        .frame(width: 72, height: 72)
                                        .overlay(
                                            Image(systemName: tool.icon)
                                                .font(.system(size: 28, weight: .medium))
                                                .foregroundStyle(.white)
                                        )
                                        .shadow(color: tool.tint.opacity(0.20), radius: 14)

                                    Text(tool.rawValue)
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.white)

                                    Text("Open in Futuristic workspace")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.white.opacity(0.64))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 190)
                                .background(
                                    UnifiedFrostPanel(corner: 24, glow: tool == .pay ? .orange : .cyan) {
                                        EmptyView()
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 22)
                    .padding(.bottom, 20)
                }

                UnifiedBottomNav(selected: .tools)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            }
        }
    }
}
