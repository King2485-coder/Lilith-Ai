import SwiftUI

struct SignUpView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var acceptedTerms = false
    @State private var showValidationError = false
    @State private var validationMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: theme.spacingXXL) {
                        VStack(spacing: theme.spacingL) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 50, weight: .light))
                                .foregroundColor(theme.accent)
                            
                            VStack(spacing: theme.spacingS) {
                                Text("Create Account")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(theme.primaryText)
                                
                                Text("Sign up to get started")
                                    .font(.system(size: 15, design: .rounded))
                                    .foregroundColor(theme.secondaryText)
                            }
                        }
                        .padding(.top, theme.spacingXXL)
                        
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
                            
                            VStack(alignment: .leading, spacing: theme.spacingS) {
                                Text("Password")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(theme.secondaryText)
                                
                                HStack(spacing: theme.spacingM) {
                                    Image(systemName: "lock")
                                        .foregroundColor(theme.tertiaryText)
                                        .frame(width: 20)
                                    
                                    SecureField("Enter password", text: $password)
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
                                
                                Text("Password must contain:\nAt least 6 characters, 1 capital letter, and 1 special character.")
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(theme.tertiaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            VStack(alignment: .leading, spacing: theme.spacingS) {
                                Text("Confirm Password")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundColor(theme.secondaryText)
                                
                                HStack(spacing: theme.spacingM) {
                                    Image(systemName: "lock")
                                        .foregroundColor(theme.tertiaryText)
                                        .frame(width: 20)
                                    
                                    SecureField("Confirm password", text: $confirmPassword)
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
                            
                            HStack(alignment: .top, spacing: theme.spacingM) {
                                Button(action: {
                                    acceptedTerms.toggle()
                                }) {
                                    Image(systemName: acceptedTerms ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 22))
                                        .foregroundColor(acceptedTerms ? theme.accent : theme.tertiaryText)
                                }
                                
                                Text("I accept the terms and conditions")
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundColor(theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            Button(action: {
                                validateAndSignUp()
                            }) {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: theme.primaryText))
                                    } else {
                                        Text("Create Account")
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
                            .disabled(authManager.isLoading || !isFormValid)
                            .opacity((authManager.isLoading || !isFormValid) ? 0.6 : 1.0)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .frame(maxWidth: 450)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, theme.spacingXXL)
                }
            }
            .navigationTitle("Sign Up")
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
        .alert("Validation Error", isPresented: $showValidationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(validationMessage)
        }
        .alert("Success", isPresented: $authManager.showError) {
            Button("OK", role: .cancel) {
                authManager.showError = false
                dismiss()
            }
        } message: {
            Text(authManager.errorMessage)
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && !confirmPassword.isEmpty && acceptedTerms
    }
    
    private func validateAndSignUp() {
        guard password.count >= 6 else {
            validationMessage = "Password must be at least 6 characters long"
            showValidationError = true
            return
        }
        
        let capitalLetterRegex = ".*[A-Z]+.*"
        let capitalLetterTest = NSPredicate(format: "SELF MATCHES %@", capitalLetterRegex)
        guard capitalLetterTest.evaluate(with: password) else {
            validationMessage = "Password must contain at least 1 capital letter"
            showValidationError = true
            return
        }
        
        let specialCharacterRegex = ".*[!@#$%^&*(),.?\":{}|<>]+.*"
        let specialCharacterTest = NSPredicate(format: "SELF MATCHES %@", specialCharacterRegex)
        guard specialCharacterTest.evaluate(with: password) else {
            validationMessage = "Password must contain at least 1 special character"
            showValidationError = true
            return
        }
        
        guard password == confirmPassword else {
            validationMessage = "Passwords do not match"
            showValidationError = true
            return
        }
        
        Task {
            await authManager.signUp(email: email, password: password)
        }
    }
}