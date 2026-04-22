import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var authStore: AuthStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Create your account")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Start with AI, secure messaging, and a Lilith ID in seconds.")
                    .foregroundStyle(LilithTheme.textSecondary)

                GlassCard {
                    VStack(spacing: 16) {
                        inputField("Name", text: $name)
                        inputField("Email", text: $email, keyboard: .emailAddress)
                        secureInput

                        Text("Your email handles sign-in and recovery. Lilith creates a username-based identity you can personalize later.")
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
                                Text("Create Account")
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(isSubmitting)
                    }
                }
            }
            .padding(20)
        }
        .background(LilithTheme.background.ignoresSafeArea())
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .keyboardAdaptive()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Back") { dismiss() }
                    .foregroundStyle(.white)
            }
        }
    }

    private var secureInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.caption.weight(.semibold))
                .foregroundStyle(LilithTheme.textSecondary)
            SecureField("Password", text: $password)
                .textInputAutocapitalization(.never)
                .padding(14)
                .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .foregroundStyle(.white)
            Text("At least 6 characters")
                .font(.caption)
                .foregroundStyle(LilithTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func inputField(_ title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
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

    private func submit() async {
        guard !name.isEmpty, !email.isEmpty, !password.isEmpty else {
            authStore.authError = "Please fill in all fields."
            return
        }

        guard password.count >= 6 else {
            authStore.authError = "Password must be at least 6 characters."
            return
        }

        isSubmitting = true
        defer { isSubmitting = false }

        let success = await authStore.register(name: name, email: email, password: password)
        if success {
            dismiss()
        }
    }
}
