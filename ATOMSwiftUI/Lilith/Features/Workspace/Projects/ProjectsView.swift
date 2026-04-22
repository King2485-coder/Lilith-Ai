import SwiftUI

struct ProjectsView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = ProjectsViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    createCard
                    projectsCard
                }
                .padding(16)
            }
            .background(LilithTheme.background.ignoresSafeArea())
            .navigationTitle("Projects")
            .task {
                guard let token = authStore.token, viewModel.projects.isEmpty else { return }
                await viewModel.load(token: token)
            }
            .refreshable {
                guard let token = authStore.token else { return }
                await viewModel.load(token: token)
            }
        }
    }

    private var createCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Create Project")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField("Project name", text: $viewModel.newProjectName)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)

                TextField("Description", text: $viewModel.newProjectDescription, axis: .vertical)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.create(token: token)
                    }
                } label: {
                    if viewModel.isCreating {
                        ProgressView().tint(.white)
                    } else {
                        Label("Create", systemImage: "plus")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var projectsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Your Projects")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                }

                if viewModel.projects.isEmpty, !viewModel.isLoading {
                    Text("No projects yet. Create one to start managing files and AI context.")
                        .font(.footnote)
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                ForEach(viewModel.projects) { project in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                if let description = project.description, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundStyle(LilithTheme.textSecondary)
                                }
                            }
                            Spacer()
                            Button(role: .destructive) {
                                Task {
                                    guard let token = authStore.token else { return }
                                    await viewModel.delete(projectId: project.id, token: token)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                        }

                        Text("\(project.files.count) files")
                            .font(.caption)
                            .foregroundStyle(LilithTheme.accentA)
                    }
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
    }
}
