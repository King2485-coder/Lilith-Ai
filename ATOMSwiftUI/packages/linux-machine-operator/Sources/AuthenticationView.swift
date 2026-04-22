import SwiftUI

struct AuthenticationView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var showSignUp = false
    @State private var showPasswordRecovery = false
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: theme.spacingXXL) {
                    Spacer(minLength: 60)
                    
                    VStack(spacing: theme.spacingL) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 60, weight: .light))
                            .foregroundColor(theme.accent)
                        
                        VStack(spacing: theme.spacingS) {
                            Text("Welcome Back")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundColor(theme.primaryText)
                            
                            Text("Sign in to manage your Linux machines")
                                .font(.system(size: 16, weight: .regular, design: .rounded))
                                .foregroundColor(theme.secondaryText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    
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
                                
                                SecureField("Enter your password", text: $password)
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
                        
                        HStack {
                            Spacer()
                            Button(action: {
                                showPasswordRecovery = true
                            }) {
                                Text("Forgot Password?")
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundColor(theme.accent)
                            }
                        }
                        
                        Button(action: {
                            Task {
                                await authManager.login(email: email, password: password)
                            }
                        }) {
                            HStack {
                                if authManager.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: theme.primaryText))
                                } else {
                                    Text("Sign In")
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
                        .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                        .opacity((authManager.isLoading || email.isEmpty || password.isEmpty) ? 0.6 : 1.0)
                    }
                    
                    HStack(spacing: theme.spacingS) {
                        Text("Don't have an account?")
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(theme.secondaryText)
                        
                        Button(action: {
                            showSignUp = true
                        }) {
                            Text("Sign Up")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.accent)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
                .frame(maxWidth: 450)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, theme.spacingXXL)
            }
        }
        .sheet(isPresented: $showSignUp) {
            SignUpView()
        }
        .sheet(isPresented: $showPasswordRecovery) {
            PasswordRecoveryView()
        }
        .alert("Error", isPresented: $authManager.showError) {
            Button("OK", role: .cancel) {
                authManager.showError = false
            }
        } message: {
            Text(authManager.errorMessage)
        }
    }
}