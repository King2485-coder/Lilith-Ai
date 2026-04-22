import SwiftUI
import WebKit
import UniformTypeIdentifiers

// MARK: - WKWebView wrapper for HTML preview

struct HTMLPreviewView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

// MARK: - IDE View

struct IDEView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = IDEViewModel()
    @State private var showFontImporter = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                toolbar
                Divider().background(Color.white.opacity(0.1))
                contentArea
            }
            .background(Color(hex: "#050505").ignoresSafeArea())
            .navigationTitle("Lilith IDE")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    autoFixToggle
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    newProjectButton
                }
            }
            .sheet(isPresented: $viewModel.showHTMLPreview) {
                htmlPreviewSheet
            }
            .fileImporter(isPresented: $showFontImporter, allowedContentTypes: [.font]) { result in
                if case .success(let url) = result {
                    viewModel.registerFont(from: url)
                }
            }
            .alert("New Project", isPresented: $viewModel.showNewProject) {
                TextField("Project name", text: $viewModel.newProjectName)
                Button("Create") {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.createProject(token: token)
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .task {
                guard let token = authStore.token else { return }
                await viewModel.loadProjects(token: token)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Project picker
                if !viewModel.projects.isEmpty {
                    Menu {
                        ForEach(viewModel.projects) { project in
                            Button(project.name) {
                                viewModel.currentProject = project
                                if let f = project.files.first {
                                    viewModel.selectFile(f.name, in: project)
                                } else {
                                    viewModel.currentFileName = nil
                                    viewModel.code = ""
                                }
                            }
                        }
                        Divider()
                        ForEach(viewModel.projects) { project in
                            Button(role: .destructive) {
                                Task {
                                    guard let token = authStore.token else { return }
                                    await viewModel.deleteProject(id: project.id, token: token)
                                }
                            } label: {
                                Label("Delete \"\(project.name)\"", systemImage: "trash")
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "folder")
                                .font(.caption)
                            Text(viewModel.currentProject?.name ?? "No Project")
                                .font(.caption.weight(.medium))
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                    }
                }

                // Font picker (IDE only)
                Menu {
                    ForEach(viewModel.availableFonts, id: \.self) { font in
                        Button {
                            viewModel.selectedFontName = font
                        } label: {
                            HStack {
                                Text(font)
                                if viewModel.selectedFontName == font {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button("Import font (.otf/.ttf)") { showFontImporter = true }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "textformat")
                        Text(viewModel.selectedFontName.isEmpty ? "Font" : viewModel.selectedFontName)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
                }

                // File tabs
                if let project = viewModel.currentProject {
                    ForEach(project.files, id: \.name) { file in
                        fileTab(file.name, isSelected: viewModel.currentFileName == file.name)
                    }

                    // Add file button
                    if viewModel.showNewFile {
                        HStack(spacing: 4) {
                            TextField("filename.py", text: $viewModel.newFileName)
                                .font(.caption.monospaced())
                                .foregroundStyle(.white)
                                .frame(width: 100)
                                .onSubmit {
                                    Task {
                                        guard let token = authStore.token else { return }
                                        await viewModel.createFile(token: token)
                                    }
                                }
                            Button {
                                viewModel.showNewFile = false
                                viewModel.newFileName = ""
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.gray)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    } else {
                        Button {
                            viewModel.showNewFile = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption)
                                .padding(6)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(height: 44)
        .background(Color(hex: "#0a0a0a"))
    }

    private func fileTab(_ name: String, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption.monospaced())
                .lineLimit(1)
            if isSelected {
                Button {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.deleteFile(name: name, token: token)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                }
                .foregroundStyle(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            isSelected
                ? Color.blue.opacity(0.25)
                : Color.white.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
        )
        .foregroundStyle(isSelected ? .white : Color.gray)
        .onTapGesture {
            if let project = viewModel.currentProject {
                viewModel.selectFile(name, in: project)
            }
        }
    }

    // MARK: - Content Area

    private var contentArea: some View {
        VStack(spacing: 0) {
            if viewModel.currentFileName != nil {
                codeEditor
                Divider().background(Color.white.opacity(0.1))
                consolePanel
            } else {
                emptyState
            }
        }
    }

    private var codeEditor: some View {
        ZStack(alignment: .topTrailing) {
            TextEditor(text: $viewModel.code)
                .font(viewModel.selectedFontName.isEmpty
                      ? .system(size: 13, weight: .regular, design: .monospaced)
                      : .custom(viewModel.selectedFontName, size: 13))
                .scrollContentBackground(.hidden)
                .foregroundStyle(.white)
                .background(Color(hex: "#0d0d0d"))
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .keyboardType(.asciiCapable)

            HStack(spacing: 8) {
                if viewModel.currentLanguage == "html" {
                    Button {
                        viewModel.showHTMLPreview = true
                    } label: {
                        Label("Preview", systemImage: "eye.fill")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.purple.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                    }
                }

                Button {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.saveFile(token: token)
                    }
                } label: {
                    Label(viewModel.isSavingFile ? "Saving…" : "Save", systemImage: "square.and.arrow.down")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }
                .disabled(viewModel.isSavingFile)
            }
            .padding(10)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Console

    private var consolePanel: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text("Console")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Spacer()

                if viewModel.consoleOutput.contains("Error") {
                    Button {
                        Task {
                            guard let token = authStore.token else { return }
                            await viewModel.manualAutoFix(token: token)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if viewModel.isAutoFixing {
                                ProgressView().scaleEffect(0.6).tint(.white)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text("Fix Error")
                        }
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                    }
                    .disabled(viewModel.isAutoFixing)
                }

                Button {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.runCode(token: token)
                    }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isRunning {
                            ProgressView().scaleEffect(0.6).tint(.white)
                        } else {
                            Image(systemName: "play.fill")
                        }
                        Text("Run")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
                }
                .disabled(viewModel.isRunning || viewModel.currentFileName == nil)

                Button {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.reviewCode(token: token)
                    }
                } label: {
                    HStack(spacing: 4) {
                        if viewModel.isReviewing {
                            ProgressView().scaleEffect(0.6).tint(.white)
                        } else {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        Text("Review")
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(.white)
                }
                .disabled(viewModel.isReviewing || viewModel.currentFileName == nil)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(hex: "#0a0a0a"))

            ScrollView {
                Text(viewModel.consoleOutput)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(viewModel.consoleOutput.contains("Error") ? Color(hex: "#ff6b6b") : Color(hex: "#a0aab4"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(height: 130)
            .background(Color(hex: "#090909"))

            if let summary = viewModel.reviewSummary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommendations")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#a0aab4"))
                    ForEach(viewModel.recommendations) { rec in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .font(.caption)
                                .foregroundStyle(Color.yellow)
                                .padding(.top, 2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.title)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                Text(rec.detail)
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: "#a0aab4"))
                            }
                        }
                        .padding(10)
                        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(hex: "#0b0b0b"))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.gray.opacity(0.4))
            Text(viewModel.projects.isEmpty ? "Create a project to start coding" : "Select or create a file")
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "#050505"))
    }

    // MARK: - HTML Preview Sheet

    private var htmlPreviewSheet: some View {
        NavigationStack {
            HTMLPreviewView(htmlContent: viewModel.code)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("HTML Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { viewModel.showHTMLPreview = false }
                    }
                }
        }
    }

    // MARK: - Toolbar accessories

    private var autoFixToggle: some View {
        Button {
            viewModel.autoFixEnabled.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "wand.and.stars")
                    .font(.caption)
                Text("Auto-Fix")
                    .font(.caption.weight(.medium))
                Text(viewModel.autoFixEnabled ? "ON" : "OFF")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(viewModel.autoFixEnabled ? .green : .gray)
            }
        }
        .foregroundStyle(viewModel.autoFixEnabled ? .blue : .gray)
    }

    private var newProjectButton: some View {
        Button {
            viewModel.showNewProject = true
        } label: {
            Image(systemName: "plus")
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Hex Color helper (already in LilithTheme likely, keep local)

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
