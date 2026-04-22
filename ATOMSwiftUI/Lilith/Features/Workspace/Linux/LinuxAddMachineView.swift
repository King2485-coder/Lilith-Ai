import SwiftUI

struct LinuxAddMachineView: View {
    @ObservedObject var viewModel: LinuxMachineViewModel
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var hostname = ""
    @State private var ipAddress = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var authMethod = "password"

    var body: some View {
        NavigationStack {
            ZStack {
                LilithTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        linuxField("Machine Name", placeholder: "e.g., Production Server", text: $name)
                        linuxField("Hostname", placeholder: "e.g., server.example.com", text: $hostname, autocap: false)
                        linuxField("IP Address", placeholder: "e.g., 192.168.1.100", text: $ipAddress, keyboard: .numbersAndPunctuation, autocap: false)
                        linuxField("Port", placeholder: "22", text: $port, keyboard: .numberPad)
                        linuxField("Username", placeholder: "e.g., root", text: $username, autocap: false)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Authentication Method")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(LilithTheme.textSecondary)

                            Picker("Auth Method", selection: $authMethod) {
                                Text("Password").tag("password")
                                Text("SSH Key").tag("ssh_key")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .frame(maxWidth: 450)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Add Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(LilithTheme.accentA)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveMachine() }
                        .foregroundColor(LilithTheme.accentA)
                        .fontWeight(.semibold)
                        .disabled(!isFormValid)
                }
            }
        }
    }

    @ViewBuilder
    private func linuxField(_ label: String, placeholder: String, text: Binding<String>,
                             keyboard: UIKeyboardType = .default, autocap: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(LilithTheme.textSecondary)

            TextField(placeholder, text: text)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(LilithTheme.textPrimary)
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap ? .sentences : .never)
                .autocorrectionDisabled(!autocap)
                .padding(14)
                .background(LilithTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LilithTheme.border, lineWidth: 1)
                )
        }
    }

    private var isFormValid: Bool {
        !name.isEmpty && !hostname.isEmpty && !ipAddress.isEmpty && !port.isEmpty && !username.isEmpty
    }

    private func saveMachine() {
        let machine = LinuxMachine(
            name: name, hostname: hostname, ipAddress: ipAddress,
            port: Int(port) ?? 22, username: username, authMethod: authMethod
        )
        viewModel.addMachine(machine)
        dismiss()
    }
}
