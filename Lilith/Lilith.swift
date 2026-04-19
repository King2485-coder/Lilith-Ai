import SwiftUI

@main
struct LilithSwiftUIApp: App {
    @StateObject private var authStore = AuthStore()
    @StateObject private var manager = LilithStateManager()
    @StateObject private var speech = LilithSpeechManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authStore)
                .environmentObject(manager)
                .environmentObject(speech)
                .preferredColorScheme(.dark)
        }
    }
}
