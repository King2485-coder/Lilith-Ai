import SwiftUI

struct SummarizerView: View {
    @State private var inputText  = ""
    @State private var summary    = ""
    @State private var isSummarizing = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Summarizer")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            // Input
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))

                if inputText.isEmpty {
                    Text("Paste text to summarize…")
                        .foregroundStyle(.secondary)
                        .padding(14)
                }

                TextEditor(text: $inputText)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .padding(10)
            }
            .frame(height: 180)
            .padding(.horizontal)

            Button {
                summarize()
            } label: {
                Label(isSummarizing ? "Summarizing…" : "Summarize", systemImage: "doc.text.magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(inputText.isEmpty || isSummarizing ? Color.gray.opacity(0.3) : Color.blue)
                    .cornerRadius(14)
                    .padding(.horizontal)
            }
            .disabled(inputText.isEmpty || isSummarizing)

            // Output
            if !summary.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Summary", systemImage: "checkmark.circle")
                        .font(.caption.bold())
                        .foregroundStyle(.blue)

                    ScrollView {
                        Text(summary)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
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
    }

    private func summarize() {
        guard !inputText.isEmpty else { return }
        isSummarizing = true
        // Placeholder: POST to /api/chat with summarization system prompt
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            summary = "Summary of your text will appear here once connected to the backend."
            isSummarizing = false
        }
    }
}

#Preview { SummarizerView() }
