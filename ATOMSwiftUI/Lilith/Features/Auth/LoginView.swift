import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    @StateObject private var serverSettings = ServerSettings()
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoginMode = true
    @State private var isSubmitting = false
    @State private var showServerSheet = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Welcome back")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(isLoginMode ? "Sign in to return to your Lilith chat, messages, calls, tools, and profile." : "Create your account to start with Lilith.")
                        .foregroundStyle(LilithTheme.textSecondary)

                    GlassCard {
                        VStack(spacing: 16) {
                            if !isLoginMode {
                                textField("Name", text: $name, keyboard: .default)
                            }
                            textField("Email", text: $email, keyboard: .emailAddress)
                            secureField("Password", text: $password)

                            Text("Lilith uses email for account access. Your communication identity stays centered on your Lilith ID, not your phone number.")
                                .font(.footnote)
                                .foregroundStyle(LilithTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let authError = authStore.authError {
                                Text(authError)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                if isSubmitting {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(isLoginMode ? "Sign In" : "Create Account")
                                }
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(isSubmitting)

                            Button(isLoginMode ? "Create Account" : "Already have an account?") {
                                isLoginMode.toggle()
                                authStore.authError = nil
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(LilithTheme.accentA)
                        }
                    }

                }
                .padding(20)
                .frame(minHeight: proxy.size.height, alignment: .topLeading)
            }
            .background(LilithTheme.background.ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { dismiss() }
                    .foregroundStyle(.white)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showServerSheet = true
                } label: {
                    Image(systemName: "network")
                }
                .foregroundStyle(.white)
            }
        }
        .sheet(isPresented: $showServerSheet) {
            NavigationStack {
                ServerSettingsView(settings: serverSettings)
                .navigationTitle("Server Settings")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { showServerSheet = false }
                    }
                }
            }
        }
    }

    private func submit() async {
        guard !email.isEmpty, !password.isEmpty else {
            authStore.authError = "Please fill in all fields."
            return
        }

        if !isLoginMode {
            guard password.count >= 6 else {
                authStore.authError = "Password must be at least 6 characters."
                return
            }
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let success: Bool
        if isLoginMode {
            success = await authStore.login(email: email, password: password)
        } else {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackName = email.split(separator: "@").first.map(String.init) ?? "Lilith User"
            let registerName = trimmedName.isEmpty ? fallbackName : trimmedName
            success = await authStore.register(name: registerName, email: email, password: password)
        }

        if success {
            dismiss()
        }
    }

    private func textField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)
            TextField(title, text: text)
                .textInputAutocapitalization(.never)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(14)
                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
        }
    }

    private func secureField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)
            SecureField(title, text: text)
                .textInputAutocapitalization(.never)
                .padding(14)
                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
        }
    }
}
