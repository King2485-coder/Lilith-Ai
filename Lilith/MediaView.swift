import SwiftUI

struct MediaView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = MediaViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    videoCard
                    imageCard
                }
                .padding(16)
            }
            .background(LilithTheme.background.ignoresSafeArea())
            .navigationTitle("Media")
        }
    }

    private var videoCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Video Generation")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField("Describe your video", text: $viewModel.videoPrompt, axis: .vertical)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)

                Picker("Duration", selection: $viewModel.selectedVideoDuration) {
                    Text("4s").tag(4)
                    Text("8s").tag(8)
                    Text("12s").tag(12)
                }
                .pickerStyle(.segmented)

                Button {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.generateVideo(token: token)
                    }
                } label: {
                    if viewModel.isGeneratingVideo {
                        ProgressView().tint(.white)
                    } else {
                        Label("Generate Video", systemImage: "video.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                if let generatedVideoStatus = viewModel.generatedVideoStatus {
                    Text(generatedVideoStatus)
                        .font(.footnote.monospaced())
                        .foregroundStyle(LilithTheme.textSecondary)
                }
            }
        }
    }

    private var imageCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Image Generation")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField("Describe your image", text: $viewModel.imagePrompt, axis: .vertical)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)

                Button {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.generateImage(token: token)
                    }
                } label: {
                    if viewModel.isGeneratingImage {
                        ProgressView().tint(.white)
                    } else {
                        Label("Generate Image", systemImage: "photo.fill")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                if let imageData = viewModel.generatedImageData {
                    let previewText = String(imageData.prefix(220)) + (imageData.count > 220 ? "..." : "")
                    Text(previewText)
                        .font(.footnote.monospaced())
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
