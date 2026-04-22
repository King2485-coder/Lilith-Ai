import SwiftUI

struct AddMachineView: View {
    @ObservedObject var theme = ThemeManager.shared
    @ObservedObject var viewModel: MachineConnectionViewModel
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
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: theme.spacingL) {
                        VStack(alignment: .leading, spacing: theme.spacingS) {
                            Text("Machine Name")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.secondaryText)
                            
                            TextField("e.g., Production Server", text: $name)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(theme.primaryText)
                                .padding(theme.spacingL)
                                .background(theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: theme.spacingS) {
                            Text("Hostname")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.secondaryText)
                            
                            TextField("e.g., server.example.com", text: $hostname)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(theme.primaryText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(theme.spacingL)
                                .background(theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: theme.spacingS) {
                            Text("IP Address")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.secondaryText)
                            
                            TextField("e.g., 192.168.1.100", text: $ipAddress)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(theme.primaryText)
                                .keyboardType(.numbersAndPunctuation)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(theme.spacingL)
                                .background(theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: theme.spacingS) {
                            Text("Port")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.secondaryText)
                            
                            TextField("22", text: $port)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(theme.primaryText)
                                .keyboardType(.numberPad)
                                .padding(theme.spacingL)
                                .background(theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: theme.spacingS) {
                            Text("Username")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.secondaryText)
                            
                            TextField("e.g., root", text: $username)
                                .font(.system(size: 16, design: .rounded))
                                .foregroundColor(theme.primaryText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(theme.spacingL)
                                .background(theme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: theme.radiusLarge))
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                        }
                        
                        VStack(alignment: .leading, spacing: theme.spacingS) {
                            Text("Authentication Method")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.secondaryText)
                            
                            Picker("Auth Method", selection: $authMethod) {
                                Text("Password").tag("password")
                                Text("SSH Key").tag("ssh_key")
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                    .frame(maxWidth: 450)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, theme.spacingXXL)
                    .padding(.vertical, theme.spacingL)
                }
            }
            .navigationTitle("Add Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(theme.accent)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMachine()
                    }
                    .foregroundColor(theme.accent)
                    .fontWeight(.semibold)
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !hostname.isEmpty && !ipAddress.isEmpty && !port.isEmpty && !username.isEmpty
    }
    
    private func saveMachine() {
        let machine = LinuxMachine(
            name: name,
            hostname: hostname,
            ipAddress: ipAddress,
            port: Int(port) ?? 22,
            username: username,
            authMethod: authMethod
        )
        viewModel.addMachine(machine)
        dismiss()
    }
}