import SwiftUI

struct LilithUnifiedHorizontalSystem: View {
    @StateObject private var appState = LilithUnifiedAppState()

    var body: some View {
        TabView(selection: $appState.currentScreen) {
            UnifiedFuturisticScreen(appState: appState)
                .tag(LilithUnifiedScreen.futuristic)

            UnifiedVoidScreen(appState: appState)
                .tag(LilithUnifiedScreen.void)

            UnifiedToolsScreen(appState: appState)
                .tag(LilithUnifiedScreen.tools)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

#Preview {
    LilithUnifiedHorizontalSystem()
}
