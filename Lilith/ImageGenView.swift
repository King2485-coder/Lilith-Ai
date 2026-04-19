import SwiftUI

@MainActor
final class ImageGenViewModel: ObservableObject {
    @Published var prompt = ""
    @Published var isGenerating = false
    @Published var imageData: String?
    @Published var errorMessage: String?

    private let apiClient = APIClient()

    func generate(token: String) async {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Enter a prompt."
            return
        }
        isGenerating = true
        imageData = nil
        errorMessage = nil
        defer { isGenerating = false }
        do {
            let response: ImageGenerationResponse = try await apiClient.request(
                "/image/generate", method: "POST",
                body: ImageGenerationPayload(prompt: trimmed),
                token: token
            )
            imageData = response.imageData
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct ImageGenView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = ImageGenViewModel()

    var onResult: ((ResultPayload) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    promptCard
                    generateButton
                    if let error = viewModel.errorMessage {
                        GlassCard {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    if let data = viewModel.imageData {
                        imageResultCard(data)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(LilithTheme.background.ignoresSafeArea())
            .navigationTitle("Image Generation")
            .navigationBarTitleDisplayMode(.inline)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .keyboardAdaptive()
    }

    private var promptCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("Describe your image", systemImage: "photo.fill")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextEditor(text: $viewModel.prompt)
                    .frame(minHeight: 100)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
        }
    }

    private var generateButton: some View {
        Button {
            Task {
                guard let token = authStore.token else { return }
                await viewModel.generate(token: token)
                if let data = viewModel.imageData {
                    onResult?(
                        ResultPayload(
                            type: .image,
                            content: "",
                            url: nil,
                            imageData: data,
                            status: .complete
                        )
                    )
                }
            }
        } label: {
            Group {
                if viewModel.isGenerating {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Generating...")
                    }
                } else {
                    Label("Generate Image", systemImage: "photo")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(viewModel.isGenerating)
    }

    private func imageResultCard(_ base64: String) -> some View {
        GlassCard {
            VStack(spacing: 12) {
                if let uiImage = base64ToImage(base64) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack {
                        Button {
                            UIPasteboard.general.image = uiImage
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        Button {
                            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
                        } label: {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(LilithTheme.accentA.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(LilithTheme.accentA)
                        }
                    }
                } else {
                    Text("Could not decode image.")
                        .foregroundStyle(.gray)
                }
            }
        }
    }

    private func base64ToImage(_ base64: String) -> UIImage? {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { return nil }
        return UIImage(data: data)
    }
}
