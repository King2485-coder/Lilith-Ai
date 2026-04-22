import SwiftUI

struct ImageGenView: View {
    @State private var prompt      = ""
    @State private var isGenerating = false
    @State private var generatedImage: UIImage? = nil

    var body: some View {
        VStack(spacing: 24) {
            Text("Image Generator")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            // Preview area
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 300)

                if isGenerating {
                    ProgressView()
                        .tint(.blue)
                        .scaleEffect(1.5)
                } else if let img = generatedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(16)
                        .frame(height: 300)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.sparkles")
                            .font(.system(size: 48))
                            .foregroundStyle(.blue.opacity(0.6))
                        Text("Your image will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal)

            // Prompt input
            HStack(spacing: 12) {
                TextField("Describe an image…", text: $prompt)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)

                Button {
                    generateImage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(prompt.isEmpty ? .gray : .blue)
                }
                .disabled(prompt.isEmpty || isGenerating)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func generateImage() {
        guard !prompt.isEmpty else { return }
        isGenerating = true
        // Placeholder: wire to DALL-E or Stable Diffusion endpoint
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isGenerating = false
            // generatedImage = <decoded UIImage from API>
        }
    }
}

#Preview { ImageGenView() }
