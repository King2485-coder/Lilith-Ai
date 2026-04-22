import SwiftUI

struct TerminalView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel: TerminalViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    
    init(machine: LinuxMachine) {
        _viewModel = StateObject(wrappedValue: TerminalViewModel(machine: machine))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Picker("View", selection: $selectedTab) {
                        Text("Terminal").tag(0)
                        Text("System Info").tag(1)
                        Text("Files").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, theme.spacingL)
                    .padding(.vertical, theme.spacingM)
                    
                    TabView(selection: $selectedTab) {
                        terminalTabView
                            .tag(0)
                        
                        SystemMonitoringView(machine: viewModel.machine)
                            .tag(1)
                        
                        FileManagerView(machine: viewModel.machine)
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationTitle(viewModel.machine.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(theme.accent)
                    }
                }
            }
        }
    }
    
    private var terminalTabView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: theme.spacingS) {
                        ForEach(viewModel.commandHistory) { command in
                            VStack(alignment: .leading, spacing: theme.spacingXS) {
                                HStack(spacing: theme.spacingS) {
                                    Text("$")
                                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                                        .foregroundColor(theme.accent)
                                    
                                    Text(command.command)
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(theme.primaryText)
                                }
                                
                                if !command.output.isEmpty {
                                    Text(command.output)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(theme.secondaryText)
                                        .padding(.leading, theme.spacingL)
                                }
                            }
                            .id(command.id)
                        }
                    }
                    .padding(theme.spacingL)
                }
                .onChange(of: viewModel.commandHistory.count) { _ in
                    if let lastCommand = viewModel.commandHistory.last {
                        withAnimation {
                            proxy.scrollTo(lastCommand.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
                .background(theme.divider)
            
            HStack(spacing: theme.spacingM) {
                HStack(spacing: theme.spacingS) {
                    Text("$")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.accent)
                    
                    TextField("Enter command", text: $viewModel.currentCommand)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundColor(theme.primaryText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onSubmit {
                            viewModel.executeCommand()
                        }
                }
                .padding(theme.spacingM)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: theme.radiusMedium))
                
                Button(action: {
                    viewModel.executeCommand()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(theme.accent)
                }
                .disabled(viewModel.currentCommand.isEmpty)
                .opacity(viewModel.currentCommand.isEmpty ? 0.5 : 1.0)
            }
            .padding(theme.spacingL)
            .background(theme.secondaryBackground)
        }
    }
}

class TerminalViewModel: ObservableObject {
    @Published var machine: LinuxMachine
    @Published var commandHistory: [TerminalCommand] = []
    @Published var currentCommand: String = ""
    
    init(machine: LinuxMachine) {
        self.machine = machine
        addWelcomeMessage()
    }
    
    private func addWelcomeMessage() {
        let welcome = TerminalCommand(
            command: "Connected to \(machine.name)",
            output: "Welcome to \(machine.hostname) (\(machine.ipAddress))\nType 'help' for available commands."
        )
        commandHistory.append(welcome)
    }
    
    func executeCommand() {
        guard !currentCommand.isEmpty else { return }
        
        let output = simulateCommandExecution(currentCommand)
        let command = TerminalCommand(command: currentCommand, output: output)
        commandHistory.append(command)
        currentCommand = ""
    }
    
    private func simulateCommandExecution(_ command: String) -> String {
        switch command.lowercased() {
        case "help":
            return "Available commands:\nls - List files\npwd - Print working directory\ndate - Show current date\nuname - System information\ntop - Process information\ndf - Disk usage\nfree - Memory usage"
        case "ls":
            return "Documents  Downloads  Pictures  Videos  Music"
        case "pwd":
            return "/home/\(machine.username)"
        case "date":
            return Date().formatted()
        case "uname":
            return "Linux \(machine.hostname) 5.15.0-generic #1 SMP x86_64 GNU/Linux"
        case "whoami":
            return machine.username
        case "clear":
            commandHistory.removeAll()
            addWelcomeMessage()
            return ""
        default:
            return "Command '\(command)' executed successfully.\n[Simulated output - connect to real machine for actual execution]"
        }
    }
}