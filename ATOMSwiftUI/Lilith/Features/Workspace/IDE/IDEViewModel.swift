import Foundation
import UIKit
import CoreText

@MainActor
final class IDEViewModel: ObservableObject {
    // MARK: - Projects
    @Published var projects: [ProjectItem] = []
    @Published var currentProject: ProjectItem?
    @Published var currentFileName: String?
    @Published var code: String = ""
    @Published var availableFonts: [String] = []
    @Published var selectedFontName: String = ""

    // MARK: - UI State
    @Published var isLoadingProjects = false
    @Published var isCreatingProject = false
    @Published var isSavingFile = false
    @Published var isRunning = false
    @Published var isAutoFixing = false
    @Published var autoFixEnabled = true
    @Published var showHTMLPreview = false
    @Published var isReviewing = false
    @Published var reviewSummary: String?
    @Published var recommendations: [CodeReviewSuggestion] = []

    // MARK: - Create forms
    @Published var newProjectName = ""
    @Published var showNewProject = false
    @Published var newFileName = ""
    @Published var showNewFile = false

    // MARK: - Output
    @Published var consoleOutput: String = "Output will appear here..."
    @Published var errorMessage: String?

    private let apiClient = APIClient()

    init() {
        loadAvailableFonts()
    }

    // MARK: - Computed

    var currentLanguage: String {
        guard let name = currentFileName else { return "text" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "py": return "python"
        case "js": return "javascript"
        case "ts": return "typescript"
        case "html": return "html"
        case "css": return "css"
        case "json": return "json"
        case "md": return "markdown"
        default: return "text"
        }
    }

    var fileIcon: String {
        guard let name = currentFileName else { return "doc" }
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "py": return "🐍"
        case "js", "ts": return "📜"
        case "html": return "🌐"
        case "css": return "🎨"
        case "json": return "📋"
        case "md": return "📝"
        default: return "📄"
        }
    }

    // MARK: - API

    func loadProjects(token: String) async {
        isLoadingProjects = true
        defer { isLoadingProjects = false }
        do {
            let result: [ProjectItem] = try await apiClient.request("/projects", token: token)
            projects = result
            if currentProject == nil, let first = result.first {
                currentProject = first
                if let firstFile = first.files.first {
                    selectFile(firstFile.name, in: first)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createProject(token: String) async {
        let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isCreatingProject = true
        defer { isCreatingProject = false }
        do {
            let project: ProjectItem = try await apiClient.request(
                "/projects", method: "POST",
                body: CreateProjectPayload(name: name, description: nil),
                token: token
            )
            projects.insert(project, at: 0)
            currentProject = project
            currentFileName = project.files.first?.name
            code = project.files.first?.content ?? ""
            newProjectName = ""
            showNewProject = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteProject(id: String, token: String) async {
        struct Empty: Decodable {}
        do {
            let _: Empty = try await apiClient.request("/projects/\(id)", method: "DELETE", token: token)
            projects.removeAll { $0.id == id }
            if currentProject?.id == id {
                currentProject = projects.first
                currentFileName = currentProject?.files.first?.name
                code = currentProject?.files.first?.content ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectFile(_ name: String, in project: ProjectItem) {
        currentFileName = name
        code = project.files.first(where: { $0.name == name })?.content ?? ""
    }

    func createFile(token: String) async {
        let name = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let project = currentProject else { return }
        do {
            let _: ProjectItem = try await apiClient.request(
                "/projects/\(project.id)/files", method: "POST",
                body: AddFilePayload(name: name, content: "", language: nil),
                token: token
            )
            let updated: ProjectItem = try await apiClient.request("/projects/\(project.id)", token: token)
            currentProject = updated
            selectFile(name, in: updated)
            newFileName = ""
            showNewFile = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteFile(name: String, token: String) async {
        guard let project = currentProject else { return }
        struct Empty: Decodable {}
        do {
            let _: Empty = try await apiClient.request(
                "/projects/\(project.id)/files/\(name)", method: "DELETE", token: token
            )
            let updated: ProjectItem = try await apiClient.request("/projects/\(project.id)", token: token)
            currentProject = updated
            if currentFileName == name {
                currentFileName = updated.files.first?.name
                code = updated.files.first?.content ?? ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveFile(token: String) async {
        guard let project = currentProject, let fileName = currentFileName else { return }
        isSavingFile = true
        defer { isSavingFile = false }
        do {
            let _: ProjectItem = try await apiClient.request(
                "/projects/\(project.id)/files/\(fileName)", method: "PUT",
                body: UpdateFilePayload(content: code),
                token: token
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func runCode(token: String) async {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        if currentLanguage == "html" {
            showHTMLPreview = true
            consoleOutput = "HTML preview opened."
            return
        }

        isRunning = true
        consoleOutput = "Running...\n"
        defer { isRunning = false }

        do {
            let result: CodeExecuteResponse = try await apiClient.request(
                "/code/execute", method: "POST",
                body: CodeExecutePayload(code: code, language: currentLanguage, projectId: currentProject?.id),
                token: token
            )
            if result.success {
                consoleOutput = result.output ?? "Executed successfully (no output)."
            } else {
                let errText = result.error ?? "Unknown error"
                consoleOutput = "Error:\n\(errText)"
                if autoFixEnabled {
                    await autoFix(error: errText, token: token)
                }
            }
        } catch {
            consoleOutput = "Error: \(error.localizedDescription)"
        }
    }

    func reviewCode(token: String) async {
        guard !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isReviewing = true
        defer { isReviewing = false }
        do {
            let result: CodeReviewResponse = try await apiClient.request(
                "/code/review",
                method: "POST",
                body: CodeReviewPayload(code: code, language: currentLanguage, projectId: currentProject?.id),
                token: token
            )
            reviewSummary = result.summary
            recommendations = result.suggestions
            if !result.summary.isEmpty {
                consoleOutput = "🔍 Code Review:\n\(result.summary)\n\n" + result.suggestions.map { "• \($0.title): \($0.detail)" }.joined(separator: "\n")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func autoFix(error: String, token: String) async {
        isAutoFixing = true
        consoleOutput += "\n\n⚡ Auto-fixing..."
        defer { isAutoFixing = false }
        do {
            let result: AutoFixLoopResponse = try await apiClient.request(
                "/code/autofix-loop", method: "POST",
                body: AutoFixLoopPayload(code: code, language: currentLanguage, projectId: currentProject?.id),
                token: token
            )
            if result.success, let fixed = result.finalCode {
                code = fixed
                let attempts = result.totalAttempts ?? 1
                consoleOutput = "✅ Auto-fixed after \(attempts) attempt(s):\n\n\(result.output ?? "")"
            } else {
                consoleOutput += "\n❌ Could not auto-fix after \(result.totalAttempts ?? 1) attempt(s)."
            }
        } catch {
            consoleOutput += "\n❌ Auto-fix failed: \(error.localizedDescription)"
        }
    }

    func manualAutoFix(token: String) async {
        guard consoleOutput.contains("Error") else { return }
        isAutoFixing = true
        defer { isAutoFixing = false }
        let errorText = consoleOutput
        do {
            let result: AutoFixResponse = try await apiClient.request(
                "/code/autofix", method: "POST",
                body: AutoFixPayload(code: code, language: currentLanguage, error: errorText, projectId: currentProject?.id),
                token: token
            )
            if result.success, let fixed = result.fixedCode {
                code = fixed
                consoleOutput = "✅ Fixed!\n\n\(result.explanation ?? "")"
            }
        } catch {
            consoleOutput = "Auto-fix failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Fonts

    func loadAvailableFonts() {
        let names = UIFont.familyNames.flatMap { UIFont.fontNames(forFamilyName: $0) }.sorted()
        availableFonts = names
        if selectedFontName.isEmpty {
            if let mono = names.first(where: { $0.lowercased().contains("mono") }) {
                selectedFontName = mono
            }
        }
    }

    func registerFont(from url: URL) {
        var error: Unmanaged<CFError>?
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        loadAvailableFonts()
    }
}
