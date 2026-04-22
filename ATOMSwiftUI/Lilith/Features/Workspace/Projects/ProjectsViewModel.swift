import Foundation

@MainActor
final class ProjectsViewModel: ObservableObject {
    @Published var projects: [ProjectItem] = []
    @Published var newProjectName = ""
    @Published var newProjectDescription = ""
    @Published var isLoading = false
    @Published var isCreating = false
    @Published var errorMessage: String?

    private let apiClient = APIClient()

    func load(token: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let response: [ProjectItem] = try await apiClient.request("/projects", token: token)
            projects = response
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(token: String) async {
        let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            errorMessage = "Project name is required."
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            let project: ProjectItem = try await apiClient.request(
                "/projects",
                method: "POST",
                body: CreateProjectPayload(name: trimmedName, description: newProjectDescription.isEmpty ? nil : newProjectDescription),
                token: token
            )
            projects.insert(project, at: 0)
            newProjectName = ""
            newProjectDescription = ""
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(projectId: String, token: String) async {
        do {
            struct EmptyResponse: Decodable {}
            let _: EmptyResponse = try await apiClient.request("/projects/\(projectId)", method: "DELETE", token: token)
            projects.removeAll { $0.id == projectId }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
