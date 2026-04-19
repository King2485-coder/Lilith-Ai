import SwiftUI

// MARK: - Projects View

struct ProjectsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = ProjectsViewModel()
    @State private var showNewProject = false
    @State private var newProjectName = ""
    @State private var selectedProject: ProjectItem? = nil

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.03).ignoresSafeArea()

                List {
                    ForEach(viewModel.projects) { project in
                        Button(action: { selectedProject = project }) {
                            HStack(spacing: 14) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(white: 0.1))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: "folder")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(Color(white: 0.6))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.name)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color(white: 0.9))

                                    Text("\(project.files.count) files · \(project.description)")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(Color(white: 0.45))
                                        .lineLimit(1)
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color(white: 0.3))
                            }
                        }
                        .listRowBackground(Color(white: 0.05))
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete(perform: deleteProjects)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Projects")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewProject = true }) {
                        Image(systemName: "plus")
                            .foregroundStyle(Color(white: 0.7))
                    }
                }
            }
            .sheet(item: $selectedProject) { project in
                ProjectDetailView(project: project, viewModel: viewModel)
            }
            .alert("New Project", isPresented: $showNewProject) {
                TextField("Name", text: $newProjectName)
                Button("Cancel", role: .cancel) { newProjectName = "" }
                Button("Create") {
                    viewModel.createProject(name: newProjectName)
                    newProjectName = ""
                }
            } message: {
                Text("Enter a name for the new project.")
            }
            .task {
                await viewModel.load(token: authStore.token)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let project = viewModel.projects[index]
            viewModel.deleteProject(id: project.id)
        }
    }
}

// MARK: - Project Detail View

struct ProjectDetailView: View {
    let project: ProjectItem
    @ObservedObject var viewModel: ProjectsViewModel
    @State private var selectedFile: ProjectFile? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.03).ignoresSafeArea()

                List {
                    Section {
                        Text(project.description)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    .listRowBackground(Color(white: 0.05))

                    Section("Files") {
                        ForEach(project.files, id: \.path) { file in
                            Button(action: { selectedFile = file }) {
                                HStack(spacing: 12) {
                                    Image(systemName: fileIcon(for: file.language))
                                        .font(.system(size: 16))
                                        .foregroundStyle(Color(white: 0.5))
                                        .frame(width: 32, height: 32)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.name)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Color(white: 0.85))
                                        Text(file.language)
                                            .font(.system(size: 11, weight: .regular))
                                            .foregroundStyle(Color(white: 0.4))
                                    }

                                    Spacer()
                                }
                            }
                            .listRowBackground(Color(white: 0.05))
                            .listRowSeparator(.hidden)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(project.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(white: 0.7))
                }
            }
            .sheet(item: $selectedFile) { file in
                FileEditorView(file: file, projectID: project.id, viewModel: viewModel)
            }
        }
        .preferredColorScheme(.dark)
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

// MARK: - File Editor View

struct FileEditorView: View {
    let file: ProjectFile
    let projectID: String
    @ObservedObject var viewModel: ProjectsViewModel
    @State private var content: String = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.03).ignoresSafeArea()

                TextEditor(text: $content)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color(white: 0.85))
                    .scrollContentBackground(.hidden)
                    .background(Color(white: 0.05))
                    .padding(8)
            }
            .navigationTitle(file.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(white: 0.6))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.updateFile(projectID: projectID, path: file.path, content: content)
                        dismiss()
                    }
                    .foregroundStyle(Color(white: 0.9))
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                content = file.content
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Projects View Model

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published var projects: [ProjectItem] = []
    @Published var errorMessage: String?

    private let apiClient = APIClient()
    private let localKey = "lilith.projects.local"

    func load(token: String?) async {
        // Try backend first
        if let token = token {
            do {
                let response: [ProjectItem] = try await apiClient.request("/projects", token: token)
                projects = response
                saveLocal()
                return
            } catch {
                // Fall back to local
            }
        }
        loadLocal()
    }

    func createProject(name: String) {
        let project = ProjectItem(
            id: UUID().uuidString,
            name: name,
            description: "Local project created in Lilith.",
            files: [],
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        projects.append(project)
        saveLocal()
    }

    func deleteProject(id: String) {
        projects.removeAll { $0.id == id }
        saveLocal()
    }

    func updateFile(projectID: String, path: String, content: String) {
        guard let pIndex = projects.firstIndex(where: { $0.id == projectID }) else { return }
        guard let fIndex = projects[pIndex].files.firstIndex(where: { $0.path == path }) else { return }
        projects[pIndex].files[fIndex].content = content
        projects[pIndex].updatedAt = ISO8601DateFormatter().string(from: Date())
        saveLocal()
    }

    // MARK: - Local persistence

    private func saveLocal() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: localKey)
        }
    }

    private func loadLocal() {
        guard let data = UserDefaults.standard.data(forKey: localKey),
              let decoded = try? JSONDecoder().decode([ProjectItem].self, from: data) else {
            // Seed with a demo project
            projects = [demoProject()]
            return
        }
        projects = decoded
    }

    private func demoProject() -> ProjectItem {
        ProjectItem(
            id: "demo-project",
            name: "Demo Project",
            description: "A starter project to explore the workspace.",
            files: [
                ProjectFile(name: "README.md", path: "/README.md", content: "# Demo Project\n\nWelcome to Lilith Projects.", language: "markdown"),
                ProjectFile(name: "main.py", path: "/main.py", content: "print('Hello from Lilith')", language: "python"),
            ],
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
    }
}
