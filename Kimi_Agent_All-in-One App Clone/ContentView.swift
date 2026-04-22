import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    @State private var showLeftPanel  = true
    @State private var showRightPanel = true
    @State private var isFocused      = false

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Main tool/dashboard area
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Left panel overlay
            HStack(spacing: 0) {
                if showLeftPanel {
                    LeftPanelView()
                        .frame(width: 260)
                        .transition(.move(edge: .leading))
                }
                Spacer()
            }

            // Right panel overlay
            HStack(spacing: 0) {
                Spacer()
                if showRightPanel {
                    RightPanelView()
                        .frame(width: 260)
                        .transition(.move(edge: .trailing))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showLeftPanel)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showRightPanel)
        .gesture(panelDragGesture)
        .onTapGesture {
            withAnimation {
                isFocused.toggle()
                showLeftPanel  = !isFocused
                showRightPanel = !isFocused
            }
        }
    }

    // MARK: - Main Content (tool router)

    @ViewBuilder
    private var mainContent: some View {
        Group {
            switch viewModel.selectedTool {
            case .imageGen:
                ImageGenView()
            case .summarize:
                SummarizerView()
            case .scanner:
                ScannerView()
            case .none:
                DefaultDashboardView()
            }
        }
    }

    // MARK: - Drag Gesture

    private var panelDragGesture: some Gesture {
        DragGesture()
            .onEnded { value in
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    if value.translation.width < -50 {
                        showLeftPanel  = false
                        showRightPanel = false
                        isFocused = true
                    }
                    if value.translation.width > 50 {
                        showLeftPanel  = true
                        showRightPanel = true
                        isFocused = false
                    }
                }
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
