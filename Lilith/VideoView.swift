import SwiftUI
import PhotosUI
import AVKit

struct VideoView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = VideoViewModel()

    @State private var photoPickerItem: PhotosPickerItem?

    var onResult: ((ResultPayload) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    modeToggle
                    if viewModel.mode == .media {
                        uploadSection
                    }
                    promptSection
                    settingsSection
                    generateButton
                    statusSection
                    if let url = viewModel.videoURL {
                        videoResult(url)
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(LilithTheme.background.ignoresSafeArea())
            .navigationTitle("Video Generation")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: photoPickerItem) { newItem in
                guard let newItem else { return }
                Task { await loadPickedMedia(newItem) }
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .keyboardAdaptive()
    }

    // MARK: - Mode Toggle

    private var modeToggle: some View {
        GlassCard {
            Picker("Mode", selection: $viewModel.mode) {
                Label("Text to Video", systemImage: "wand.and.stars").tag(VideoViewModel.VideoMode.text)
                Label("From Photo/Video", systemImage: "photo.on.rectangle").tag(VideoViewModel.VideoMode.media)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Upload Section

    private var uploadSection: some View {
        GlassCard {
            VStack(spacing: 12) {
                if let data = viewModel.uploadedPhotoData, let uiImage = UIImage(data: data) {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        Button {
                            viewModel.uploadedPhotoData = nil
                            photoPickerItem = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .padding(6)
                    }
                    Text(viewModel.uploadedFileName)
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                } else {
                    PhotosPicker(selection: $photoPickerItem, matching: .any(of: [.images, .videos])) {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(LilithTheme.accentA.opacity(0.15))
                                    .frame(width: 56, height: 56)
                                Image(systemName: "plus")
                                    .font(.title2)
                                    .foregroundStyle(LilithTheme.accentA)
                            }
                            Text("Select Image or Video")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                            Text("JPG, PNG, WebP, MP4, MOV")
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                .foregroundStyle(Color.white.opacity(0.15))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Prompt

    private var promptSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.mode == .media ? "Describe how to animate it..." : "Describe your video...")
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)

                TextEditor(text: $viewModel.prompt)
                    .frame(minHeight: 90)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        GlassCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Size").font(.caption).foregroundStyle(LilithTheme.textSecondary)
                    Picker("Size", selection: $viewModel.selectedSize) {
                        Text("HD 720p").tag("1280x720")
                        Text("Wide").tag("1792x1024")
                        Text("Portrait").tag("1024x1792")
                        Text("Square").tag("1024x1024")
                    }
                    .pickerStyle(.menu)
                    .tint(.white)
                }

                Divider().background(Color.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Duration").font(.caption).foregroundStyle(LilithTheme.textSecondary)
                    Picker("Duration", selection: $viewModel.selectedDuration) {
                        ForEach(viewModel.durationOptions, id: \.self) { s in
                            Text("\(s)s").tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    // MARK: - Generate Button

    private var generateButton: some View {
        Button {
            Task {
                guard let token = authStore.token else { return }
                await viewModel.generate(token: token)
                if let url = viewModel.videoURL {
                    onResult?(
                        ResultPayload(
                            type: .video,
                            content: "",
                            url: url,
                            imageData: nil,
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
                    Label("Generate Video", systemImage: "play.fill")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryButtonStyle())
        .disabled(viewModel.isGenerating)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusSection: some View {
        if let status = viewModel.videoStatus {
            GlassCard {
                HStack(spacing: 12) {
                    Circle()
                        .fill(statusColor(status))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(status.capitalized)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        if status == "processing" {
                            Text("This may take 2–10 minutes.")
                                .font(.caption)
                                .foregroundStyle(LilithTheme.textSecondary)
                        }
                    }
                }
            }
        }
        if let error = viewModel.errorMessage {
            GlassCard {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "completed": return .green
        case "failed": return .red
        default: return .yellow
        }
    }

    // MARK: - Video Result

    private func videoResult(_ url: URL) -> some View {
        GlassCard {
            VStack(spacing: 10) {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                Link(destination: url) {
                    Label("Download / Open", systemImage: "arrow.down.circle")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(LilithTheme.accentA)
                }
            }
        }
    }

    // MARK: - Load Picked Media

    private func loadPickedMedia(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self) {
            viewModel.uploadedPhotoData = data
            if let contentType = item.supportedContentTypes.first {
                let identifier = contentType.identifier
                if identifier.contains("jpeg") {
                    viewModel.uploadedMimeType = "image/jpeg"
                    viewModel.uploadedFileName = "upload.jpg"
                } else if identifier.contains("png") {
                    viewModel.uploadedMimeType = "image/png"
                    viewModel.uploadedFileName = "upload.png"
                } else if identifier.contains("webp") {
                    viewModel.uploadedMimeType = "image/webp"
                    viewModel.uploadedFileName = "upload.webp"
                } else if identifier.contains("mp4") || identifier.contains("mpeg4") {
                    viewModel.uploadedMimeType = "video/mp4"
                    viewModel.uploadedFileName = "upload.mp4"
                } else if identifier.contains("quicktime") {
                    viewModel.uploadedMimeType = "video/quicktime"
                    viewModel.uploadedFileName = "upload.mov"
                } else {
                    viewModel.uploadedMimeType = "image/jpeg"
                    viewModel.uploadedFileName = "upload.jpg"
                }
            }
        }
    }
}
