import SwiftUI

struct RightPanelView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var temperature: Double = 0.7
    @State private var streamEnabled = true

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 0)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text("Settings")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.top, 56)
                .padding(.bottom, 16)

                Divider().background(Color.white.opacity(0.15))

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Model selector
                        settingsSection(title: "Model") {
                            Picker("Model", selection: .constant("gpt-4o")) {
                                Text("GPT-4o").tag("gpt-4o")
                                Text("GPT-4o mini").tag("gpt-4o-mini")
                                Text("Claude 3.5").tag("claude-3.5")
                            }
                            .pickerStyle(.segmented)
                        }

                        // Temperature slider
                        settingsSection(title: "Temperature  \(String(format: "%.1f", temperature))") {
                            Slider(value: $temperature, in: 0...1, step: 0.1)
                                .tint(.blue)
                        }

                        // Stream toggle
                        settingsSection(title: "Streaming") {
                            Toggle("Stream responses", isOn: $streamEnabled)
                                .tint(.blue)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                        }

                        // Active tool indicator
                        settingsSection(title: "Active Tool") {
                            HStack {
                                if let tool = viewModel.selectedTool {
                                    Label(tool.rawValue, systemImage: tool.icon)
                                        .font(.subheadline)
                                        .foregroundStyle(.blue)
                                } else {
                                    Text("Dashboard")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Clear") {
                                    viewModel.selectTool(nil)
                                }
                                .font(.caption)
                                .foregroundStyle(.red.opacity(0.8))
                            }
                        }
                    }
                    .padding(16)
                }

                Spacer()
            }
        }
        .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            content()
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
    }
}

#Preview {
    RightPanelView()
        .environmentObject(AppViewModel())
        .background(Color.black)
}
