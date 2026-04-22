import SwiftUI

struct MachineConnectionView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel = MachineConnectionViewModel()
    @State private var showAddMachine = false
    @State private var showProfile = false
    @State private var selectedMachine: LinuxMachine?
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                if viewModel.machines.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: theme.spacingL) {
                            ForEach(viewModel.machines) { machine in
                                MachineCardView(machine: machine) {
                                    selectedMachine = machine
                                }
                            }
                        }
                        .padding(.horizontal, theme.spacingL)
                        .padding(.top, theme.spacingM)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("My Machines")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showAddMachine = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.accent)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        showProfile = true
                    }) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddMachine) {
            AddMachineView(viewModel: viewModel)
        }
        .sheet(isPresented: $showProfile) {
            AboutView()
        }
        .fullScreenCover(item: $selectedMachine) { machine in
            TerminalView(machine: machine)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: theme.spacingXL) {
            Image(systemName: "server.rack")
                .font(.system(size: 60, weight: .light))
                .foregroundColor(theme.tertiaryText)
            
            VStack(spacing: theme.spacingS) {
                Text("No Machines")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.primaryText)
                
                Text("Add your first Linux machine to get started")
                    .font(.system(size: 16, design: .rounded))
                    .foregroundColor(theme.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: {
                showAddMachine = true
            }) {
                HStack(spacing: theme.spacingM) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Machine")
                }
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(theme.primaryText)
                .frame(height: 52)
                .padding(.horizontal, theme.spacingXXL)
                .background(
                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                        .fill(theme.tertiaryBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: theme.radiusLarge)
                        .stroke(theme.border, lineWidth: 1)
                )
            }
        }
        .padding(theme.spacingXXL)
    }
}

struct MachineCardView: View {
    @ObservedObject var theme = ThemeManager.shared
    let machine: LinuxMachine
    let onConnect: () -> Void
    
    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: theme.spacingL) {
                ZStack {
                    RoundedRectangle(cornerRadius: theme.radiusMedium)
                        .fill(theme.accentSubtle)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "server.rack")
                        .font(.system(size: 24))
                        .foregroundColor(theme.accent)
                }
                
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(machine.name)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)
                    
                    Text(machine.ipAddress)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundColor(theme.secondaryText)
                    
                    HStack(spacing: theme.spacingXS) {
                        Circle()
                            .fill(machine.isConnected ? theme.success : theme.tertiaryText)
                            .frame(width: 8, height: 8)
                        
                        Text(machine.isConnected ? "Connected" : "Disconnected")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(theme.tertiaryText)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(theme.tertiaryText)
            }
            .padding(theme.spacingL)
            .background(
                RoundedRectangle(cornerRadius: theme.radiusXL)
                    .fill(theme.cardBackground)
                    .shadow(color: theme.shadowColor, radius: theme.shadowRadiusMedium, x: 0, y: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: theme.radiusXL)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

class MachineConnectionViewModel: ObservableObject {
    @Published var machines: [LinuxMachine] = []
    
    init() {
        loadMachines()
    }
    
    func loadMachines() {
        if let data = UserDefaults.standard.data(forKey: "saved_machines"),
           let decoded = try? JSONDecoder().decode([LinuxMachine].self, from: data) {
            machines = decoded
        }
    }
    
    func addMachine(_ machine: LinuxMachine) {
        machines.append(machine)
        saveMachines()
    }
    
    func deleteMachine(_ machine: LinuxMachine) {
        machines.removeAll { $0.id == machine.id }
        saveMachines()
    }
    
    private func saveMachines() {
        if let encoded = try? JSONEncoder().encode(machines) {
            UserDefaults.standard.set(encoded, forKey: "saved_machines")
        }
    }
}