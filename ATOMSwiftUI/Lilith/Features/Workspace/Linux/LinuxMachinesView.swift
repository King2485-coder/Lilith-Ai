import SwiftUI

// MARK: - Main Linux Machines View

struct LinuxMachinesView: View {
    @StateObject private var viewModel = LinuxMachineViewModel()
    @State private var showAddMachine = false
    @State private var selectedMachine: LinuxMachine?

    var body: some View {
        NavigationStack {
            ZStack {
                LilithTheme.background.ignoresSafeArea()

                if viewModel.machines.isEmpty {
                    linuxEmptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.machines) { machine in
                                LinuxMachineCard(machine: machine) {
                                    selectedMachine = machine
                                } onDelete: {
                                    viewModel.deleteMachine(machine)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                    }
                }
            }
            .navigationTitle("Linux Machines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddMachine = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(LilithTheme.accentA)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddMachine) {
            LinuxAddMachineView(viewModel: viewModel)
        }
        .fullScreenCover(item: $selectedMachine) { machine in
            LinuxTerminalView(machine: machine)
        }
    }

    private var linuxEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "server.rack")
                .font(.system(size: 56, weight: .light))
                .foregroundColor(LilithTheme.accentA.opacity(0.5))

            VStack(spacing: 8) {
                Text("No Machines")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(LilithTheme.textPrimary)

                Text("Add your first Linux machine to get started")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(LilithTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { showAddMachine = true }) {
                HStack(spacing: 10) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Machine")
                }
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(LilithTheme.accentA)
                .padding(.horizontal, 24)
                .frame(height: 48)
                .background(LilithTheme.accentA.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(LilithTheme.accentA.opacity(0.3), lineWidth: 1)
                )
            }
        }
        .padding(32)
    }
}

// MARK: - Machine Card

struct LinuxMachineCard: View {
    let machine: LinuxMachine
    let onConnect: () -> Void
    let onDelete: () -> Void
    @State private var showDeleteConfirm = false

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LilithTheme.accentA.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: "server.rack")
                        .font(.system(size: 22))
                        .foregroundColor(LilithTheme.accentA)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(machine.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(LilithTheme.textPrimary)
                        .lineLimit(1)

                    Text("\(machine.username)@\(machine.ipAddress):\(machine.port)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(LilithTheme.textSecondary)

                    HStack(spacing: 6) {
                        Circle()
                            .fill(machine.isConnected ? Color.green : Color.white.opacity(0.25))
                            .frame(width: 7, height: 7)

                        Text(machine.isConnected ? "Connected" : "Ready to connect")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.38))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.25))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LilithTheme.surface)
                    .shadow(color: Color.black.opacity(0.3), radius: 14, x: 0, y: 6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(LilithTheme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .confirmationDialog("Delete \(machine.name)?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { onDelete() }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - ViewModel

class LinuxMachineViewModel: ObservableObject {
    @Published var machines: [LinuxMachine] = []

    init() { loadMachines() }

    func loadMachines() {
        if let data = UserDefaults.standard.data(forKey: "lilith_linux_machines"),
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
            UserDefaults.standard.set(encoded, forKey: "lilith_linux_machines")
        }
    }
}
