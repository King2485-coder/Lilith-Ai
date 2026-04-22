import SwiftUI

// MARK: - File Manager

struct LinuxFileManagerView: View {
    @StateObject private var viewModel: LinuxFileManagerViewModel
    @State private var selectedFile: LinuxFileItem?
    @State private var showDetails = false

    init(machine: LinuxMachine) {
        _viewModel = StateObject(wrappedValue: LinuxFileManagerViewModel(machine: machine))
    }

    var body: some View {
        ZStack {
            LilithTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Path bar
                HStack(spacing: 10) {
                    Button(action: { viewModel.navigateUp() }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18))
                            .foregroundColor(viewModel.currentPath == "/"
                                ? Color.white.opacity(0.25)
                                : LilithTheme.accentA)
                            .frame(width: 40, height: 40)
                    }
                    .disabled(viewModel.currentPath == "/")

                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(viewModel.currentPath)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(LilithTheme.textSecondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button(action: { viewModel.loadFiles() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundColor(LilithTheme.accentA)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(LilithTheme.surface)

                Divider().background(LilithTheme.border)

                if viewModel.files.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "folder")
                            .font(.system(size: 44, weight: .light))
                            .foregroundColor(Color.white.opacity(0.25))
                        Text("Empty Directory")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(LilithTheme.textPrimary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.files) { file in
                                LinuxFileRow(file: file) {
                                    if file.isDirectory {
                                        viewModel.navigateToDirectory(file.name)
                                    } else {
                                        selectedFile = file
                                        showDetails = true
                                    }
                                }

                                if file.id != viewModel.files.last?.id {
                                    Divider()
                                        .background(LilithTheme.border)
                                        .padding(.leading, 56)
                                }
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .sheet(isPresented: $showDetails) {
            if let file = selectedFile {
                LinuxFileDetailsView(file: file)
            }
        }
        .onAppear { viewModel.loadFiles() }
    }
}

// MARK: - File Row

struct LinuxFileRow: View {
    let file: LinuxFileItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 22))
                    .foregroundColor(file.isDirectory ? LilithTheme.accentA : LilithTheme.textSecondary)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(file.name)
                        .font(.system(size: 15, design: .rounded))
                        .foregroundColor(LilithTheme.textPrimary)
                        .lineLimit(1)

                    if !file.isDirectory {
                        HStack(spacing: 6) {
                            if !file.size.isEmpty {
                                Text(file.size)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.38))
                            }
                            if !file.modifiedDate.isEmpty {
                                Text("·")
                                    .foregroundColor(Color.white.opacity(0.25))
                                Text(file.modifiedDate)
                                    .font(.system(size: 12, design: .rounded))
                                    .foregroundColor(Color.white.opacity(0.38))
                            }
                        }
                    }
                }

                Spacer()

                if file.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.25))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - File Details Sheet

struct LinuxFileDetailsView: View {
    @Environment(\.dismiss) var dismiss
    let file: LinuxFileItem

    var body: some View {
        NavigationStack {
            ZStack {
                LilithTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 52))
                                .foregroundColor(LilithTheme.accentA)
                            Text(file.name)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(LilithTheme.textPrimary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 24)

                        VStack(spacing: 0) {
                            linuxDetailRow("Size", value: file.size.isEmpty ? "—" : file.size)
                            Divider().background(LilithTheme.border).padding(.leading, 14)
                            linuxDetailRow("Modified", value: file.modifiedDate.isEmpty ? "—" : file.modifiedDate)
                            Divider().background(LilithTheme.border).padding(.leading, 14)
                            linuxDetailRow("Permissions", value: file.permissions.isEmpty ? "—" : file.permissions)
                        }
                        .background(LilithTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LilithTheme.border, lineWidth: 1))
                        .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: 450)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("File Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(LilithTheme.accentA)
                }
            }
        }
    }

    private func linuxDetailRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(LilithTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(LilithTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - ViewModel

class LinuxFileManagerViewModel: ObservableObject {
    @Published var files: [LinuxFileItem] = []
    @Published var currentPath = "/home"

    private var machine: LinuxMachine

    init(machine: LinuxMachine) {
        self.machine = machine
    }

    func loadFiles() {
        if currentPath == "/home" || currentPath == "/home/\(machine.username)" {
            files = [
                LinuxFileItem(name: "Documents", isDirectory: true),
                LinuxFileItem(name: "Downloads", isDirectory: true),
                LinuxFileItem(name: "Pictures", isDirectory: true),
                LinuxFileItem(name: "Videos", isDirectory: true),
                LinuxFileItem(name: ".ssh", isDirectory: true),
                LinuxFileItem(name: ".bashrc", isDirectory: false, size: "3.2 KB", modifiedDate: "Jan 15, 2025", permissions: "rw-r--r--"),
                LinuxFileItem(name: "config.txt", isDirectory: false, size: "2.4 KB", modifiedDate: "Jan 14, 2025", permissions: "rw-r--r--"),
                LinuxFileItem(name: "script.sh", isDirectory: false, size: "1.1 KB", modifiedDate: "Jan 13, 2025", permissions: "rwxr-xr-x"),
                LinuxFileItem(name: "data.json", isDirectory: false, size: "15.7 KB", modifiedDate: "Jan 12, 2025", permissions: "rw-r--r--"),
            ]
        } else {
            files = [
                LinuxFileItem(name: "README.md", isDirectory: false, size: "4.1 KB", modifiedDate: "Jan 10, 2025", permissions: "rw-r--r--"),
                LinuxFileItem(name: "index.html", isDirectory: false, size: "12.3 KB", modifiedDate: "Jan 9, 2025", permissions: "rw-r--r--"),
            ]
        }
    }

    func navigateToDirectory(_ name: String) {
        currentPath = currentPath.hasSuffix("/") ? "\(currentPath)\(name)" : "\(currentPath)/\(name)"
        loadFiles()
    }

    func navigateUp() {
        guard currentPath != "/" else { return }
        let components = currentPath.split(separator: "/").map(String.init)
        if components.count > 1 {
            currentPath = "/" + components.dropLast().joined(separator: "/")
        } else {
            currentPath = "/"
        }
        loadFiles()
    }
}
