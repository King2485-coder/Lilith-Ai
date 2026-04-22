import SwiftUI

// MARK: - System Monitor

struct LinuxSystemMonitorView: View {
    @StateObject private var viewModel: LinuxSystemMonitorViewModel
    @State private var processesExpanded = true
    @State private var networkExpanded = true

    init(machine: LinuxMachine) {
        _viewModel = StateObject(wrappedValue: LinuxSystemMonitorViewModel(machine: machine))
    }

    var body: some View {
        ZStack {
            LilithTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    // Auto-refresh row
                    HStack {
                        Toggle("Auto-Refresh", isOn: $viewModel.autoRefresh)
                            .font(.system(size: 14, design: .rounded))
                            .foregroundColor(LilithTheme.textPrimary)
                            .tint(LilithTheme.accentA)

                        Spacer()

                        Button(action: { viewModel.refreshData() }) {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundColor(LilithTheme.accentA)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Metric cards
                    Group {
                        LinuxMetricCard(icon: "cpu", title: "CPU Usage",
                                        value: "\(Int(viewModel.systemInfo.cpuUsage))%",
                                        progress: viewModel.systemInfo.cpuUsage / 100)

                        LinuxMetricCard(icon: "memorychip", title: "Memory",
                                        value: "\(viewModel.systemInfo.memoryUsed) / \(viewModel.systemInfo.memoryTotal)",
                                        progress: viewModel.systemInfo.memoryPercentage / 100)

                        LinuxMetricCard(icon: "internaldrive", title: "Disk Usage",
                                        value: viewModel.systemInfo.diskUsage,
                                        progress: viewModel.systemInfo.diskPercentage / 100)
                    }
                    .padding(.horizontal, 16)

                    // Network — collapsible
                    VStack(spacing: 0) {
                        Button(action: { withAnimation(.spring(response: 0.3)) { networkExpanded.toggle() } }) {
                            HStack(spacing: 10) {
                                Image(systemName: "network")
                                    .font(.system(size: 18))
                                    .foregroundColor(LilithTheme.accentA)
                                Text("Network")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(LilithTheme.textPrimary)
                                Spacer()
                                Image(systemName: networkExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.38))
                            }
                            .padding(14)
                        }
                        .buttonStyle(.plain)

                        if networkExpanded {
                            Text(viewModel.systemInfo.networkInfo)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(LilithTheme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.bottom, 14)
                        }
                    }
                    .background(LilithTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LilithTheme.border, lineWidth: 1))
                    .padding(.horizontal, 16)

                    // Processes — collapsible
                    VStack(spacing: 0) {
                        Button(action: { withAnimation(.spring(response: 0.3)) { processesExpanded.toggle() } }) {
                            HStack(spacing: 10) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 18))
                                    .foregroundColor(LilithTheme.accentA)
                                Text("Running Processes")
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundColor(LilithTheme.textPrimary)
                                Spacer()
                                Image(systemName: processesExpanded ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.38))
                            }
                            .padding(14)
                        }
                        .buttonStyle(.plain)

                        if processesExpanded {
                            VStack(spacing: 0) {
                                ForEach(viewModel.processes) { process in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(process.name)
                                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                                .foregroundColor(LilithTheme.textPrimary)
                                            Text("PID: \(process.pid)")
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(Color.white.opacity(0.38))
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 3) {
                                            Text("\(Int(process.cpuUsage))% CPU")
                                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                                .foregroundColor(LilithTheme.accentA)
                                            Text(process.memoryUsage)
                                                .font(.system(size: 11, design: .rounded))
                                                .foregroundColor(Color.white.opacity(0.38))
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)

                                    if process.id != viewModel.processes.last?.id {
                                        Divider().background(LilithTheme.border).padding(.leading, 14)
                                    }
                                }
                            }
                            .padding(.bottom, 4)
                        }
                    }
                    .background(LilithTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LilithTheme.border, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear { viewModel.refreshData() }
    }
}

// MARK: - Metric Card

struct LinuxMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(LilithTheme.accentA)
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(LilithTheme.textPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(LilithTheme.accentA)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LilithTheme.elevated)
                        .frame(height: 7)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LilithTheme.accentA)
                        .frame(width: geo.size.width * min(max(progress, 0), 1), height: 7)
                }
            }
            .frame(height: 7)
        }
        .padding(14)
        .background(LilithTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LilithTheme.border, lineWidth: 1))
    }
}

// MARK: - ViewModel

class LinuxSystemMonitorViewModel: ObservableObject {
    @Published var systemInfo = LinuxSystemInfo()
    @Published var processes: [LinuxProcessInfo] = []
    @Published var autoRefresh = false {
        didSet { autoRefresh ? startTimer() : stopTimer() }
    }

    private var machine: LinuxMachine
    private var refreshTimer: Timer?

    init(machine: LinuxMachine) {
        self.machine = machine
        loadSimulated()
    }

    func refreshData() { loadSimulated() }

    private func loadSimulated() {
        systemInfo = LinuxSystemInfo(
            cpuUsage: Double.random(in: 20...75),
            memoryTotal: "16 GB",
            memoryUsed: "\(Int.random(in: 4...12)) GB",
            memoryPercentage: Double.random(in: 30...75),
            diskUsage: "\(Int.random(in: 100...400)) GB / 500 GB",
            diskPercentage: Double.random(in: 20...80),
            networkInfo: "eth0: \(machine.ipAddress)\nRX: 1.4 GB | TX: 920 MB"
        )
        processes = [
            LinuxProcessInfo(pid: "1", name: "systemd", cpuUsage: Double.random(in: 0.5...3), memoryUsage: "\(Int.random(in: 40...120)) MB"),
            LinuxProcessInfo(pid: "1234", name: "nginx", cpuUsage: Double.random(in: 3...12), memoryUsage: "\(Int.random(in: 80...220)) MB"),
            LinuxProcessInfo(pid: "5678", name: "postgres", cpuUsage: Double.random(in: 8...22), memoryUsage: "\(Int.random(in: 180...480)) MB"),
            LinuxProcessInfo(pid: "9012", name: "docker", cpuUsage: Double.random(in: 4...18), memoryUsage: "\(Int.random(in: 120...380)) MB"),
            LinuxProcessInfo(pid: "3456", name: "sshd", cpuUsage: Double.random(in: 0.2...2), memoryUsage: "\(Int.random(in: 15...40)) MB"),
        ]
    }

    private func startTimer() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }

    private func stopTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    deinit { stopTimer() }
}
