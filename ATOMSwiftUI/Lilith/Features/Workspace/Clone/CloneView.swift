import SwiftUI
import WebKit

// MARK: - WebView for site preview

struct SitePreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView { WKWebView() }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.load(URLRequest(url: url))
    }
}

// MARK: - Clone View

struct CloneView: View {
    @EnvironmentObject private var authStore: AuthStore
    @StateObject private var viewModel = CloneViewModel()
    @State private var showCopied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    urlInputCard
                    if let result = viewModel.cloneResult {
                        resultCard(result)
                    }
                }
                .padding(16)
            }
            .background(LilithTheme.background.ignoresSafeArea())
            .navigationTitle("Site Cloner")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $viewModel.showPreview) {
                previewSheet
            }
        }
    }

    // MARK: - URL Input

    private var urlInputCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "globe")
                        .foregroundStyle(LilithTheme.accentA)
                    Text("Site Cloner")
                        .font(.headline)
                        .foregroundStyle(.white)
                }

                Text("Enter a URL to clone its HTML structure.")
                    .font(.caption)
                    .foregroundStyle(LilithTheme.textSecondary)

                TextField("https://example.com", text: $viewModel.urlInput)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .padding(14)
                    .background(LilithTheme.elevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(.white)
                    .onSubmit {
                        Task {
                            guard let token = authStore.token else { return }
                            await viewModel.cloneSite(token: token)
                        }
                    }

                if let error = viewModel.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }

                Button {
                    Task {
                        guard let token = authStore.token else { return }
                        await viewModel.cloneSite(token: token)
                    }
                } label: {
                    if viewModel.isLoading {
                        HStack(spacing: 8) {
                            ProgressView().tint(.white)
                            Text("Cloning...")
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        Label("Clone Site", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isLoading || viewModel.urlInput.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Result Card

    private func resultCard(_ result: CloneSiteResponse) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Cloned Successfully")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(result.code.count) chars")
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                }

                HStack(spacing: 12) {
                    Button {
                        UIPasteboard.general.string = result.code
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            showCopied = false
                        }
                    } label: {
                        Label(showCopied ? "Copied!" : "Copy HTML", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)
                    }

                    if viewModel.previewURL != nil {
                        Button {
                            viewModel.showPreview = true
                        } label: {
                            Label("Preview", systemImage: "safari")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(LilithTheme.accentA.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(LilithTheme.accentA)
                        }
                    }
                }

                ScrollView {
                    Text(result.code)
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(Color(red: 0.7, green: 0.8, blue: 1.0))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(height: 260)
                .background(Color(red: 0.05, green: 0.05, blue: 0.07), in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LilithTheme.border, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Preview Sheet

    private var previewSheet: some View {
        NavigationStack {
            Group {
                if let url = viewModel.previewURL {
                    SitePreviewView(url: url)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    Text("Preview unavailable")
                        .foregroundStyle(.gray)
                }
            }
            .navigationTitle("Site Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { viewModel.showPreview = false }
                }
            }
        }
    }
}
