import SwiftUI

struct FileManagerView: View {
    @ObservedObject var theme = ThemeManager.shared
    @StateObject private var viewModel: FileManagerViewModel
    @State private var showFileDetails = false
    @State private var selectedFile: FileItem?
    
    init(machine: LinuxMachine) {
        _viewModel = StateObject(wrappedValue: FileManagerViewModel(machine: machine))
    }
    
    var body: some View {
        ZStack {
            theme.primaryBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack(spacing: theme.spacingM) {
                    Button(action: {
                        viewModel.navigateUp()
                    }) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20))
                            .foregroundColor(theme.accent)
                            .frame(width: 44, height: 44)
                    }
                    .disabled(viewModel.currentPath == "/")
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(viewModel.currentPath)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(theme.secondaryText)
                    }
                }
                .padding(.horizontal, theme.spacingL)
                .padding(.vertical, theme.spacingM)
                .background(theme.secondaryBackground)
                
                Divider()
                    .background(theme.divider)
                
                if viewModel.files.isEmpty {
                    VStack(spacing: theme.spacingL) {
                        Image(systemName: "folder")
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(theme.tertiaryText)
                        
                        Text("Empty Directory")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundColor(theme.primaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.files) { file in
                                FileRowView(file: file) {
                                    if file.isDirectory {
                                        viewModel.navigateToDirectory(file.name)
                                    } else {
                                        selectedFile = file
                                        showFileDetails = true
                                    }
                                }
                                
                                if file.id != viewModel.files.last?.id {
                                    Divider()
                                        .background(theme.divider)
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .padding(.bottom, theme.spacingXXL)
                    }
                }
            }
        }
        .sheet(isPresented: $showFileDetails) {
            if let file = selectedFile {
                FileDetailsView(file: file)
            }
        }
        .onAppear {
            viewModel.loadFiles()
        }
    }
}

struct FileRowView: View {
    @ObservedObject var theme = ThemeManager.shared
    let file: FileItem
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: theme.spacingM) {
                Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                    .font(.system(size: 24))
                    .foregroundColor(file.isDirectory ? theme.accent : theme.secondaryText)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: theme.spacingXS) {
                    Text(file.name)
                        .font(.system(size: 16, design: .rounded))
                        .foregroundColor(theme.primaryText)
                        .lineLimit(1)
                    
                    if !file.isDirectory {
                        HStack(spacing: theme.spacingS) {
                            Text(file.size)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundColor(theme.tertiaryText)
                            
                            if !file.modifiedDate.isEmpty {
                                Text("•")
                                    .foregroundColor(theme.tertiaryText)
                                
                                Text(file.modifiedDate)
                                    .font(.system(size: 13, design: .rounded))
                                    .foregroundColor(theme.tertiaryText)
                            }
                        }
                    }
                }
                
                Spacer()
                
                if file.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(theme.tertiaryText)
                }
            }
            .padding(.horizontal, theme.spacingL)
            .padding(.vertical, theme.spacingM)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct FileDetailsView: View {
    @ObservedObject var theme = ThemeManager.shared
    @Environment(\.dismiss) var dismiss
    let file: FileItem
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.primaryBackground
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: theme.spacingL) {
                        VStack(spacing: theme.spacingL) {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 60))
                                .foregroundColor(theme.accent)
                            
                            Text(file.name)
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(theme.primaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, theme.spacingXXL)
                        
                        VStack(alignment: .leading, spacing: theme.spacingM) {
                            DetailRow(label: "Size", value: file.size)
                            DetailRow(label: "Modified", value: file.modifiedDate)
                            DetailRow(label: "Permissions", value: file.permissions)
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
                    .frame(maxWidth: 450)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, theme.spacingL)
                }
            }
            .navigationTitle("File Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(theme.accent)
                }
            }
        }
    }
}

struct DetailRow: View {
    @ObservedObject var theme = ThemeManager.shared
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(theme.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(theme.primaryText)
        }
    }
}

class FileManagerViewModel: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var currentPath: String = "/home"
    
    private var machine: LinuxMachine
    
    init(machine: LinuxMachine) {
        self.machine = machine
    }
    
    func loadFiles() {
        files = [
            FileItem(name: "Documents", isDirectory: true),
            FileItem(name: "Downloads", isDirectory: true),
            FileItem(name: "Pictures", isDirectory: true),
            FileItem(name: "Videos", isDirectory: true),
            FileItem(name: "config.txt", isDirectory: false, size: "2.4 KB", modifiedDate: "Jan 15, 2025", permissions: "rw-r--r--"),
            FileItem(name: "script.sh", isDirectory: false, size: "1.1 KB", modifiedDate: "Jan 14, 2025", permissions: "rwxr-xr-x"),
            FileItem(name: "data.json", isDirectory: false, size: "15.7 KB", modifiedDate: "Jan 13, 2025", permissions: "rw-r--r--")
        ]
    }
    
    func navigateToDirectory(_ name: String) {
        currentPath = currentPath + "/" + name
        loadFiles()
    }
    
    func navigateUp() {
        guard currentPath != "/" else { return }
        let components = currentPath.split(separator: "/")
        if components.count > 1 {
            currentPath = "/" + components.dropLast().joined(separator: "/")
        } else {
            currentPath = "/"
        }
        loadFiles()
    }
}