import SwiftUI

struct SystemMonitoringView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel: SystemMonitoringViewModel
    
    init(machine: LinuxMachine) {
        _viewModel = StateObject(wrappedValue: SystemMonitoringViewModel(machine: machine))
    }
    
    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: theme.spacingL) {
                    HStack {
                        Toggle("Auto-Refresh", isOn: $viewModel.autoRefresh)
                            .font(.system(size: 15, design: .rounded))
                            .foregroundColor(theme.primaryText)
                        
                        Spacer()
                        
                        Button(action: {
                            viewModel.refreshData()
                        }) {
                            HStack(spacing: theme.spacingS) {
                                Image(systemName: "arrow.clockwise")
                                Text("Refresh")
                            }
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(theme.accent)
                        }
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.top, theme.spacingM)
                    
                    VStack(spacing: theme.spacingL) {
                        SystemInfoCard(
                            icon: "cpu",
                            title: "CPU Usage",
                            value: "\(Int(viewModel.systemInfo.cpuUsage))%",
                            progress: viewModel.systemInfo.cpuUsage / 100
                        )
                        
                        SystemInfoCard(
                            icon: "memorychip",
                            title: "Memory",
                            value: "\(viewModel.systemInfo.memoryUsed) / \(viewModel.systemInfo.memoryTotal)",
                            progress: viewModel.systemInfo.memoryPercentage / 100
                        )
                        
                        SystemInfoCard(
                            icon: "internaldrive",
                            title: "Disk Usage",
                            value: viewModel.systemInfo.diskUsage,
                            progress: viewModel.systemInfo.diskPercentage / 100
                        )
                        
                        VStack(alignment: .leading, spacing: theme.spacingM) {
                            HStack(spacing: theme.spacingM) {
                                Image(systemName: "network")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.accent)
                                
                                Text("Network")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(theme.primaryText)
                            }
                            
                            Text(viewModel.systemInfo.networkInfo)
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundColor(theme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(theme.spacingL)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radiusLarge)
                                .fill(theme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radiusLarge)
                                .stroke(theme.border, lineWidth: 1)
                        )
                        
                        VStack(alignment: .leading, spacing: theme.spacingM) {
                            HStack(spacing: theme.spacingM) {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 20))
                                    .foregroundColor(theme.accent)
                                
                                Text("Running Processes")
                                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                                    .foregroundColor(theme.primaryText)
                            }
                            
                            ForEach(viewModel.processes) { process in
                                HStack {
                                    VStack(alignment: .leading, spacing: theme.spacingXS) {
                                        Text(process.name)
                                            .font(.system(size: 14, weight: .medium, design: .rounded))
                                            .foregroundColor(theme.primaryText)
                                        
                                        Text("PID: \(process.pid)")
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundColor(theme.tertiaryText)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: theme.spacingXS) {
                                        Text("\(Int(process.cpuUsage))%")
                                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                                            .foregroundColor(theme.accent)
                                        
                                        Text(process.memoryUsage)
                                            .font(.system(size: 12, design: .rounded))
                                            .foregroundColor(theme.tertiaryText)
                                    }
                                }
                                .padding(.vertical, theme.spacingS)
                                
                                if process.id != viewModel.processes.last?.id {
                                    Divider()
                                        .background(theme.divider)
                                }
                            }
                        }
                        .padding(theme.spacingL)
                        .background(
                            RoundedRectangle(cornerRadius: theme.radiusLarge)
                                .fill(theme.cardBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.radiusLarge)
                                .stroke(theme.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, theme.spacingL)
                    .padding(.bottom, theme.spacingXXL)
                }
            }
        }
        .onAppear {
            viewModel.refreshData()
        }
    }
}

struct SystemInfoCard: View {
    @ObservedObject var theme = ThemeManager.shared
    let icon: String
    let title: String
    let value: String
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingM) {
            HStack(spacing: theme.spacingM) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(theme.accent)
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(theme.primaryText)
                
                Spacer()
                
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(theme.accent)
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: theme.radiusSmall)
                        .fill(theme.tertiaryBackground)
                        .frame(height: 8)
                    
                    RoundedRectangle(cornerRadius: theme.radiusSmall)
                        .fill(theme.accent)
                        .frame(width: geometry.size.width * progress, height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(theme.spacingL)
        .background(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: theme.radiusLarge)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}

class SystemMonitoringViewModel: ObservableObject {
    @Published var systemInfo: SystemInfo
    @Published var processes: [ProcessInfo] = []
    @Published var autoRefresh: Bool = false {
        didSet {
            if autoRefresh {
                startAutoRefresh()
            } else {
                stopAutoRefresh()
            }
        }
    }
    
    private var machine: LinuxMachine
    private var refreshTimer: Timer?
    
    init(machine: LinuxMachine) {
        self.machine = machine
        self.systemInfo = SystemInfo()
        loadSimulatedData()
    }
    
    func refreshData() {
        loadSimulatedData()
    }
    
    private func loadSimulatedData() {
        systemInfo = SystemInfo(
            cpuUsage: Double.random(in: 20...80),
            memoryTotal: "16 GB",
            memoryUsed: "\(Int.random(in: 4...12)) GB",
            memoryPercentage: Double.random(in: 30...75),
            diskUsage: "\(Int.random(in: 100...400)) GB / 500 GB",
            diskPercentage: Double.random(in: 20...80),
            networkInfo: "eth0: 192.168.1.100\nRX: 1.2 GB | TX: 850 MB"
        )
        
        processes = [
            ProcessInfo(pid: "1234", name: "systemd", cpuUsage: Double.random(in: 1...5), memoryUsage: "\(Int.random(in: 50...200)) MB"),
            ProcessInfo(pid: "5678", name: "nginx", cpuUsage: Double.random(in: 5...15), memoryUsage: "\(Int.random(in: 100...300)) MB"),
            ProcessInfo(pid: "9012", name: "postgres", cpuUsage: Double.random(in: 10...25), memoryUsage: "\(Int.random(in: 200...500)) MB"),
            ProcessInfo(pid: "3456", name: "docker", cpuUsage: Double.random(in: 5...20), memoryUsage: "\(Int.random(in: 150...400)) MB"),
            ProcessInfo(pid: "7890", name: "sshd", cpuUsage: Double.random(in: 1...3), memoryUsage: "\(Int.random(in: 20...50)) MB")
        ]
    }
    
    private func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.refreshData()
        }
    }
    
    private func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    deinit {
        stopAutoRefresh()
    }
}