import SwiftUI

// MARK: - Terminal View (tabbed: Terminal, System, Files)

struct LinuxTerminalView: View {
    @StateObject private var viewModel: LinuxTerminalViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    init(machine: LinuxMachine) {
        _viewModel = StateObject(wrappedValue: LinuxTerminalViewModel(machine: machine))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LilithTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("View", selection: $selectedTab) {
                        Text("Terminal").tag(0)
                        Text("System").tag(1)
                        Text("Files").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    TabView(selection: $selectedTab) {
                        terminalTab.tag(0)
                        LinuxSystemMonitorView(machine: viewModel.machine).tag(1)
                        LinuxFileManagerView(machine: viewModel.machine).tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle(viewModel.machine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(LilithTheme.accentA)
                    }
                }
            }
        }
    }

    private var terminalTab: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.commandHistory) { cmd in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text("$")
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundColor(LilithTheme.accentA)
                                    Text(cmd.command)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(LilithTheme.textPrimary)
                                }
                                if !cmd.output.isEmpty {
                                    Text(cmd.output)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundColor(LilithTheme.textSecondary)
                                        .padding(.leading, 16)
                                }
                            }
                            .id(cmd.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: viewModel.commandHistory.count) { _, _ in
                    if let last = viewModel.commandHistory.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Divider().background(LilithTheme.border)

            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("$")
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(LilithTheme.accentA)

                    TextField("Enter command", text: $viewModel.currentCommand)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(LilithTheme.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit { viewModel.executeCommand() }
                }
                .padding(12)
                .background(LilithTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button(action: { viewModel.executeCommand() }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundColor(viewModel.currentCommand.isEmpty
                            ? LilithTheme.accentA.opacity(0.3)
                            : LilithTheme.accentA)
                }
                .disabled(viewModel.currentCommand.isEmpty)
            }
            .padding(14)
            .background(LilithTheme.surface)
        }
    }
}

// MARK: - ViewModel

class LinuxTerminalViewModel: ObservableObject {
    @Published var machine: LinuxMachine
    @Published var commandHistory: [LinuxTerminalCommand] = []
    @Published var currentCommand = ""

    init(machine: LinuxMachine) {
        self.machine = machine
        let welcome = LinuxTerminalCommand(
            command: "Connected to \(machine.name)",
            output: "Welcome to \(machine.hostname) (\(machine.ipAddress))\nType 'help' for available commands."
        )
        commandHistory.append(welcome)
    }

    func executeCommand() {
        guard !currentCommand.isEmpty else { return }
        let output = simulate(currentCommand)
        commandHistory.append(LinuxTerminalCommand(command: currentCommand, output: output))
        currentCommand = ""
    }

    private func simulate(_ cmd: String) -> String {
        switch cmd.lowercased().trimmingCharacters(in: .whitespaces) {
        case "help":
            return "Available: ls, pwd, date, uname, whoami, top, df, free, clear, hostname, uptime"
        case "ls":
            return "Documents  Downloads  Pictures  Videos  Music  .bashrc  .ssh"
        case "pwd":
            return "/home/\(machine.username)"
        case "date":
            return Date().formatted()
        case "uname", "uname -a":
            return "Linux \(machine.hostname) 5.15.0-generic #1 SMP x86_64 GNU/Linux"
        case "whoami":
            return machine.username
        case "hostname":
            return machine.hostname
        case "uptime":
            return " up 14 days,  3:42,  2 users,  load average: 0.15, 0.12, 0.10"
        case "top", "htop":
            return "PID  USER  CPU%  MEM%  COMMAND\n1234  root   2.1   1.5  systemd\n5678  www    8.4   3.2  nginx\n9012  pg     12.3  5.8  postgres"
        case "df", "df -h":
            return "Filesystem   Size  Used Avail Use%\n/dev/sda1    500G  210G  290G  42%"
        case "free", "free -h":
            return "         total  used  free\nMem:      16G    8G    8G\nSwap:     2G     0G    2G"
        case "clear":
            commandHistory.removeAll()
            return ""
        default:
            return "Command '\(cmd)' executed.\n[Simulated — connect a real SSH session for live execution]"
        }
    }
}
