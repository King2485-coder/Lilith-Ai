import SwiftUI

struct PasswordRecoveryView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    @State private var step = 1
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: theme.spacingXXL) {
                        VStack(spacing: theme.spacingL) {
                            Image(systemName: "key.fill")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(theme.accent)
                            
                            VStack(spacing: theme.spacingS) {
                                Text("Password Recovery")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.primaryText)
                                
                                Text(step == 1 ? "Enter your email to receive a recovery code" : "Enter the code and set a new password")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(theme.secondaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.top, theme.spacingXXL)
                        
                        if step == 1 {
                            VStack(spacing: theme.spacingL) {
                                VStack(alignment: .leading, spacing: theme.spacingS) {
                                    Text("Email")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(theme.secondaryText)
                                    
                                    HStack(spacing: theme.spacingM) {
                                        Image(systemName: "envelope")
                                            .foregroundColor(theme.tertiaryText)
                                            .frame(width: 20)
                                        
                                        TextField("Enter your email", text: $email)
                                            .font(.system(size: 16, design: .rounded))
                                            .foregroundColor(theme.primaryText)
                                            .textInputAutocapitalization(.never)
                                            .keyboardType(.emailAddress)
                                            .autocorrectionDisabled()
                                    }
                                    .padding(theme.spacingL)
                                    .background(theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusLarge)
                                            .stroke(theme.border, lineWidth: 1)
                                    )
                                }
                                
                                Button(action: {
                                    sendRecoveryEmail()
                                }) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: theme.primaryText))
                                        } else {
                                            Text("Send Recovery Email")
                                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                                .foregroundColor(theme.primaryText)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: theme.radiusLarge)
                                            .fill(theme.tertiaryBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusLarge)
                                            .stroke(theme.border, lineWidth: 1)
                                    )
                                }
                                .disabled(isLoading || email.isEmpty)
                                .opacity((isLoading || email.isEmpty) ? 0.6 : 1.0)
                            }
                        } else {
                            VStack(spacing: theme.spacingL) {
                                VStack(alignment: .leading, spacing: theme.spacingS) {
                                    Text("Verification Code")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(theme.secondaryText)
                                    
                                    HStack(spacing: theme.spacingM) {
                                        Image(systemName: "lock.shield")
                                            .foregroundColor(theme.tertiaryText)
                                            .frame(width: 20)
                                        
                                        TextField("Enter code", text: $verificationCode)
                                            .font(.system(size: 16, design: .rounded))
                                            .foregroundColor(theme.primaryText)
                                            .textInputAutocapitalization(.characters)
                                            .keyboardType(.numberPad)
                                    }
                                    .padding(theme.spacingL)
                                    .background(theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusLarge)
                                            .stroke(theme.border, lineWidth: 1)
                                    )
                                }
                                
                                VStack(alignment: .leading, spacing: theme.spacingS) {
                                    Text("New Password")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(theme.secondaryText)
                                    
                                    HStack(spacing: theme.spacingM) {
                                        Image(systemName: "lock")
                                            .foregroundColor(theme.tertiaryText)
                                            .frame(width: 20)
                                        
                                        SecureField("Enter new password", text: $newPassword)
                                            .font(.system(size: 16, design: .rounded))
                                            .foregroundColor(theme.primaryText)
                                            .textInputAutocapitalization(.never)
                                    }
                                    .padding(theme.spacingL)
                                    .background(theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusLarge)
                                            .stroke(theme.border, lineWidth: 1)
                                    )
                                }
                                
                                VStack(alignment: .leading, spacing: theme.spacingS) {
                                    Text("Confirm New Password")
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(theme.secondaryText)
                                    
                                    HStack(spacing: theme.spacingM) {
                                        Image(systemName: "lock")
                                            .foregroundColor(theme.tertiaryText)
                                            .frame(width: 20)
                                        
                                        SecureField("Confirm new password", text: $confirmNewPassword)
                                            .font(.system(size: 16, design: .rounded))
                                            .foregroundColor(theme.primaryText)
                                            .textInputAutocapitalization(.never)
                                    }
                                    .padding(theme.spacingL)
                                    .background(theme.cardBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusLarge)
                                            .stroke(theme.border, lineWidth: 1)
                                    )
                                }
                                
                                Button(action: {
                                    resetPassword()
                                }) {
                                    HStack {
                                        if isLoading {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: theme.primaryText))
                                        } else {
                                            Text("Reset Password")
                                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                                .foregroundColor(theme.primaryText)
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(
                                        RoundedRectangle(cornerRadius: theme.radiusLarge)
                                            .fill(theme.tertiaryBackground)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: theme.radiusLarge)
                                            .stroke(theme.border, lineWidth: 1)
                                    )
                                }
                                .disabled(isLoading || verificationCode.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty)
                                .opacity((isLoading || verificationCode.isEmpty || newPassword.isEmpty || confirmNewPassword.isEmpty) ? 0.6 : 1.0)
                            }
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: 450)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, theme.spacingXXL)
                }
            }
            .navigationTitle("Password Recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(theme.accent)
                }
            }
        }
        .alert("Message", isPresented: $showAlert) {
            Button("OK", role: .cancel) {
                if alertMessage.contains("successfully") {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func sendRecoveryEmail() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            alertMessage = "Recovery email sent! Please check your inbox for the verification code."
            showAlert = true
            step = 2
        }
    }
    
    private func resetPassword() {
        guard newPassword == confirmNewPassword else {
            alertMessage = "Passwords do not match"
            showAlert = true
            return
        }
        
        guard newPassword.count >= 6 else {
            alertMessage = "Password must be at least 6 characters long"
            showAlert = true
            return
        }
        
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isLoading = false
            alertMessage = "Password reset successfully! You can now login with your new password."
            showAlert = true
        }
    }
}