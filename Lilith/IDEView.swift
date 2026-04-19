import SwiftUI

// MARK: - IDE View

struct IDEView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = IDEViewModel()
    @State private var selectedFile: IDEFile?
    @State private var showNewFile = false
    @State private var newFileName = ""

    let languages = ["Swift", "Python", "JavaScript", "HTML", "CSS", "JSON", "Markdown"]

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.03).ignoresSafeArea()

                HStack(spacing: 0) {
                    // Sidebar: file tree
                    fileSidebar
                        .frame(width: 220)

                    Divider()
                        .background(Color(white: 0.12))

                    // Editor
                    editorArea
                }
            }
            .navigationTitle("Builder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Run") { Task { await viewModel.run(token: authStore.token) } }
                        Button("Review") { Task { await viewModel.review(token: authStore.token) } }
                        Button("Auto-Fix") { Task { await viewModel.autoFix(token: authStore.token) } }
                    } label: {
                        Image(systemName: "play.circle")
                            .foregroundStyle(Color(white: 0.7))
                    }
                }
            }
            .alert("New File", isPresented: $showNewFile) {
                TextField("Name", text: $newFileName)
                Button("Cancel", role: .cancel) { newFileName = "" }
                Button("Create") {
                    viewModel.createFile(name: newFileName)
                    newFileName = ""
                }
            } message: {
                Text("Enter a file name with extension.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - File Sidebar

    private var fileSidebar: some View {
        List {
            Section {
                Button(action: { showNewFile = true }) {
                    Label("New File", systemImage: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.7))
                }
                .listRowBackground(Color(white: 0.05))
            }

            Section("Files") {
                ForEach(viewModel.files) { file in
                    Button(action: { selectedFile = file }) {
                        HStack(spacing: 10) {
                            Image(systemName: fileIcon(for: file.language))
                                .font(.system(size: 13))
                                .foregroundStyle(Color(white: 0.5))
                                .frame(width: 24)

                            Text(file.name)
                                .font(.system(size: 13, weight: selectedFile?.id == file.id ? .semibold : .regular))
                                .foregroundStyle(selectedFile?.id == file.id ? Color(white: 0.9) : Color(white: 0.65))

                            Spacer()
                        }
                    }
                    .listRowBackground(Color(white: 0.05))
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteFiles)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(white: 0.03))
    }

    // MARK: - Editor Area

    private var editorArea: some View {
        VStack(spacing: 0) {
            if let file = selectedFile {
                TextEditor(text: binding(for: file))
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(white: 0.85))
                    .scrollContentBackground(.hidden)
                    .background(Color(white: 0.03))
                    .padding(8)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(white: 0.2))
                    Text("Select a file to edit")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color(white: 0.4))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Output panel
            if !viewModel.output.isEmpty || viewModel.isRunning {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().background(Color(white: 0.12))

                    HStack {
                        Text("Output")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(white: 0.45))
                        Spacer()
                        if viewModel.isRunning {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Button(action: { viewModel.output = "" }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color(white: 0.4))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                    ScrollView {
                        Text(viewModel.output)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(viewModel.isError ? Color.red.opacity(0.8) : Color(white: 0.7))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 180)
                }
                .background(Color(white: 0.04))
            }
        }
    }

    private func binding(for file: IDEFile) -> Binding<String> {
        guard let index = viewModel.files.firstIndex(where: { $0.id == file.id }) else {
            return .constant("")
        }
        return Binding(
            get: { viewModel.files[index].content },
            set: { viewModel.files[index].content = $0 }
        )
    }

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let file = viewModel.files[index]
            viewModel.deleteFile(id: file.id)
        }
    }

    private func fileIcon(for language: String) -> String {
        switch language.lowercased() {
        case "swift": return "swift"
        case "python": return "terminal"
        case "javascript", "typescript", "js", "ts": return "globe"
        case "html": return "safari"
        case "css": return "paintbrush"
        case "json": return "curlybraces"
        case "markdown", "md": return "text.alignleft"
        default: return "doc.text"
        }
    }
}

// MARK: - IDE File

struct IDEFile: Identifiable, Equatable, Codable {
    let id: String
    var name: String
    var content: String
    var language: String
}

// MARK: - IDE View Model

@MainActor
final class IDEViewModel: ObservableObject {
    @Published var files: [IDEFile] = []
    @Published var output: String = ""
    @Published var isRunning: Bool = false
    @Published var isError: Bool = false

    private let apiClient = APIClient()
    private let localKey = "lilith.ide.files"

    init() {
        loadLocal()
        if files.isEmpty {
            seedDemoFiles()
        }
    }

    func createFile(name: String) {
        let lang = language(from: name)
        let file = IDEFile(
            id: UUID().uuidString,
            name: name,
            content: "",
            language: lang
        )
        files.append(file)
        saveLocal()
    }

    func deleteFile(id: String) {
        files.removeAll { $0.id == id }
        saveLocal()
    }

    func run(token: String?) async {
        guard let file = files.first(where: { !$0.content.isEmpty }) else {
            output = "No file content to run."
            isError = true
            return
        }
        isRunning = true
        isError = false
        output = "Running \(file.name)..."
        defer { isRunning = false }

        if let token = token {
            do {
                let response: CodeExecuteResponse = try await apiClient.request(
                    "/code/execute",
                    method: "POST",
                    body: ["code": file.content, "language": file.language],
                    token: token
                )
                output = response.output
                isError = !response.success
                return
            } catch {
                // Fallback to chat-style execution
            }
        }

        // Local fallback: just echo the content
        output = "[Local run] \(file.language.uppercased())\n---\n\(file.content)"
        isError = false
    }

    func review(token: String?) async {
        guard let file = files.first(where: { !$0.content.isEmpty }) else {
            output = "No file content to review."
            isError = true
            return
        }
        isRunning = true
        isError = false
        defer { isRunning = false }

        if let token = token {
            do {
                let response: CodeReviewResponse = try await apiClient.request(
                    "/code/review",
                    method: "POST",
                    body: ["code": file.content, "language": file.language],
                    token: token
                )
                let suggestions = response.suggestions.map { "• [\($0.severity.uppercased())] \($0.title): \($0.detail)" }.joined(separator: "\n")
                output = "Summary: \(response.summary)\n\nSuggestions:\n\(suggestions)"
                return
            } catch { }
        }

        output = "Code review unavailable offline. Connect to a backend for AI-powered review."
        isError = false
    }

    func autoFix(token: String?) async {
        guard let file = files.first(where: { !$0.content.isEmpty }) else {
            output = "No file content to fix."
            isError = true
            return
        }
        isRunning = true
        isError = false
        defer { isRunning = false }

        if let token = token {
            do {
                let response: AutoFixResponse = try await apiClient.request(
                    "/code/autofix",
                    method: "POST",
                    body: ["code": file.content, "language": file.language],
                    token: token
                )
                if response.success, let index = files.firstIndex(where: { $0.id == file.id }) {
                    files[index].content = response.fixedCode
                    saveLocal()
                }
                output = response.explanation
                return
            } catch { }
        }

        output = "Auto-fix unavailable offline. Connect to a backend for AI-powered fixes."
        isError = false
    }

    // MARK: - Helpers

    private func language(from filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "py": return "python"
        case "js": return "javascript"
        case "ts": return "typescript"
        case "html", "htm": return "html"
        case "css": return "css"
        case "json": return "json"
        case "md": return "markdown"
        default: return "text"
        }
    }

    private func seedDemoFiles() {
        files = [
            IDEFile(id: "demo-1", name: "main.swift", content: "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        Text(\"Hello, Lilith!\")\n    }\n}", language: "swift"),
            IDEFile(id: "demo-2", name: "script.py", content: "def greet(name):\n    return f\"Hello, {name}!\"\n\nprint(greet(\"Lilith\"))", language: "python"),
        ]
        saveLocal()
    }

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(files) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let decoded = try? JSONDecoder().decode([IDEFile].self, from: data) else { return }
        files = decoded
    }
}
