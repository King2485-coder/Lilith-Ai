import SwiftUI
import AVFoundation

struct ScannerView: View {
    @State private var scannedText = ""
    @State private var isScanning  = false
    @State private var showCamera  = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Document Scanner")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            // Viewfinder placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1.5
                            )
                    )

                if isScanning {
                    ProgressView("Extracting text…")
                        .tint(.blue)
                        .foregroundStyle(.white)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue.opacity(0.7))
                        Text("Tap to scan a document")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 280)
            .padding(.horizontal)
            .onTapGesture { showCamera = true }

            // Scan button
            Button {
                showCamera = true
            } label: {
                Label("Open Camera", systemImage: "camera.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(14)
                    .padding(.horizontal)
            }

            // Extracted text output
            if !scannedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Extracted Text", systemImage: "text.alignleft")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)

                    ScrollView {
                        Text(scannedText)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .cornerRadius(14)
                .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        // Wire VisionKit / AVCaptureSession here via sheet
    }
}

#Preview { ScannerView() }
