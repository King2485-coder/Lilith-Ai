import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        Group {
            if authStore.isAuthenticated {
#if LILITH_INTEGRATION
                LilithHomeView()
#else
                MainWorkspacePlaceholderView(username: authStore.user?.username ?? "lilith")
#endif
            } else {
                AuthenticationPlaceholderView {
                    Task {
                        await authStore.login(
                            email: AuthStore.rememberedEmail,
                            password: AuthStore.rememberedPassword
                        )
                    }
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task {
            await authStore.restoreSessionIfNeeded()
        }
    }
}

private struct AuthenticationPlaceholderView: View {
    var onSignIn: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Lilith")
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Enter the void.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Sign In") {
                onSignIn()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color(white: 0.85), in: Capsule())
            .foregroundStyle(.black)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}

private struct MainWorkspacePlaceholderView: View {
    let username: String

    var body: some View {
        VStack(spacing: 12) {
            Text("Welcome, @\(username)")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)

            Text("Lilith iOS target now builds from CLI.")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(Color(white: 0.4))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }
}
