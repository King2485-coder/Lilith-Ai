import SwiftUI
import SafariServices

// MARK: - Clone View

struct CloneView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = CloneViewModel()
    @State private var showSafari = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.03).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // URL Input
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Website URL")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(white: 0.5))

                            HStack(spacing: 12) {
                                TextField("https://example.com", text: $viewModel.urlString)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(Color(white: 0.9))
                                    .tint(Color(white: 0.5))
                                    .keyboardType(.URL)
                                    .textContentType(.URL)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)

                                if viewModel.isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Button(action: {
                                        Task {
                                            await viewModel.clone(token: authStore.token)
                                        }
                                    }) {
                                        Text("Clone")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color(white: 0.85))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.urlString.isEmpty)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(white: 0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(Color(white: 0.14).opacity(0.4), lineWidth: 0.5)
                                    )
                            )
                        }
                        .padding(.horizontal, 16)

                        // Result
                        if let result = viewModel.result {
                            resultCard(result)
                                .padding(.horizontal, 16)
                        }

                        // Error
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.red.opacity(0.8))
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.red.opacity(0.08))
                                )
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Website Clone")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSafari) {
            if let url = viewModel.previewURL {
                SafariView(url: url)
            }
        }
    }

    // MARK: - Result Card

    private func resultCard(_ result: CloneSiteResponse) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.green.opacity(0.7))

                Text("Cloned successfully")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(white: 0.9))

                Spacer()
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Source")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color(white: 0.4))
                Text(result.url)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(white: 0.65))
                    .lineLimit(1)
            }

            // Code preview
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Extracted Code")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(white: 0.4))
                    Spacer()
                    Button(action: {
                        UIPasteboard.general.string = result.code
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.5))
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    Text(result.code)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color(white: 0.7))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 240)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(white: 0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color(white: 0.14).opacity(0.3), lineWidth: 0.5)
                        )
                )
            }

            HStack(spacing: 10) {
                if let previewURL = URL(string: result.previewUrl) {
                    Button(action: {
                        viewModel.previewURL = previewURL
                        showSafari = true
                    }) {
                        Label("Preview", systemImage: "safari")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(white: 0.85))
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    UIPasteboard.general.string = result.code
                }) {
                    Label("Copy Code", systemImage: "doc.on.doc")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.8))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(white: 0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color(white: 0.14).opacity(0.4), lineWidth: 0.5)
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(white: 0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(white: 0.14).opacity(0.4), lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Clone View Model

@MainActor
final class CloneViewModel: ObservableObject {
    @Published var urlString: String = ""
    @Published var result: CloneSiteResponse?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var previewURL: URL?

    private let apiClient = APIClient()

    func clone(token: String?) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a URL first."
            return
        }
        guard trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") else {
            errorMessage = "URL must start with http:// or https://"
            return
        }

        isLoading = true
        errorMessage = nil
        result = nil
        defer { isLoading = false }

        if let token = token {
            do {
                let response: CloneSiteResponse = try await apiClient.request(
                    "/clone",
                    method: "POST",
                    body: ["url": trimmed],
                    token: token
                )
                result = response
                if let url = URL(string: response.previewUrl) {
                    previewURL = url
                }
                return
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        errorMessage = "No backend connection. Clone requires a running Lilith server."
    }
}

// MARK: - Safari View

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
