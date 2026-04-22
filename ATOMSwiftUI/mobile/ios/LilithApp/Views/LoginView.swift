import SwiftUI

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Text("Lilith Login").font(.title2).bold()
            TextField("Username", text: $vm.username)
                .textFieldStyle(.roundedBorder)
            SecureField("Password", text: $vm.password)
                .textFieldStyle(.roundedBorder)
            Button("Login") {
                Task { await vm.login() }
            }
            .buttonStyle(.borderedProminent)
            if let user = vm.currentUser {
                Text("Logged in as \(user.username)")
            }
            if let error = vm.error {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
        .padding()
    }
}

