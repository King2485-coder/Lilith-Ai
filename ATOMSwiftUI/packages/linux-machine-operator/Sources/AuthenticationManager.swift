import Foundation
import SwiftUI

class AuthenticationManager: ObservableObject {
    static let shared = AuthenticationManager()
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: AppUser?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    
    private init() {
        checkAuthStatus()
    }
    
    private func checkAuthStatus() {
        if let userId = UserDefaults.standard.string(forKey: "user_id"),
           let email = UserDefaults.standard.string(forKey: "user_email") {
            currentUser = AppUser(id: userId, email: email, provider: "email")
            isAuthenticated = true
        }
    }
    
    func login(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            showError = false
        }
        
        do {
            let user = try await NetworkService.shared.loginUser(email: email, password: password)
            
            await MainActor.run {
                self.currentUser = user
                self.isAuthenticated = true
                self.isLoading = false
                
                if let userId = user.id {
                    UserDefaults.standard.set(userId, forKey: "user_id")
                }
                if let userEmail = user.email {
                    UserDefaults.standard.set(userEmail, forKey: "user_email")
                }
                UserDefaults.standard.set("email", forKey: "login_provider")
            }
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func signUp(email: String, password: String) async {
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            showError = false
        }
        
        do {
            let user = try await NetworkService.shared.createUser(email: email, password: password)
            
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Account created successfully. Please login."
                self.showError = true
            }
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    func logout() {
        currentUser = nil
        isAuthenticated = false
        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_email")
        UserDefaults.standard.removeObject(forKey: "login_provider")
    }
    
    func deleteAccount() async {
        guard let userId = currentUser?.id else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            try await NetworkService.shared.deleteUser(userId: userId)
            await MainActor.run {
                self.logout()
                self.isLoading = false
            }
        } catch is CancellationError {
            return
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to delete account: \(error.localizedDescription)"
                self.showError = true
                self.isLoading = false
            }
        }
    }
}