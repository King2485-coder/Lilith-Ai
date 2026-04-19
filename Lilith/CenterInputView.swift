import SwiftUI

// MARK: - Center Input View
// Single minimal text input at rest. Centered. Bottom-safe-area.

struct CenterInputView: View {
    @ObservedObject var viewModel: ChatViewModel
    @EnvironmentObject private var speech: LilithSpeechManager
    @Binding var isFocused: Bool
    var onSend: () -> Void
    var onOpenTools: () -> Void

    @FocusState private var textFieldFocused: Bool
    @State private var showSendButton = false

    var body: some View {
        VStack(spacing: 0) {
            // Small drag handle to open tool layer
            Button(action: onOpenTools) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(white: 0.25).opacity(0.4))
                    .frame(width: 36, height: 4)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 10)

            // Input field
            HStack(spacing: 10) {
                // Voice button
                Button(action: {
                    if speech.isListening {
                        speech.stopListening()
                    } else {
                        speech.startListening()
                    }
                }) {
                    Image(systemName: speech.isListening ? "waveform" : "mic")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(speech.isListening ? Color.red.opacity(0.8) : Color(white: 0.5))
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color(white: 0.08))
                        )
                }
                .buttonStyle(.plain)

                TextField("Speak to the void…", text: $viewModel.draft, axis: .vertical)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color(white: 0.9))
                    .tint(Color(white: 0.6))
                    .focused($textFieldFocused)
                    .lineLimit(1...4)
                    .onChange(of: textFieldFocused) { focused in
                        isFocused = focused
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSendButton = focused || !viewModel.draft.isEmpty
                        }
                    }
                    .onChange(of: viewModel.draft) { draft in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showSendButton = textFieldFocused || !draft.isEmpty
                        }
                    }
                    .onChange(of: speech.transcript) { transcript in
                        if speech.isListening {
                            viewModel.draft = transcript
                        }
                    }

                if showSendButton {
                    Button(action: {
                        onSend()
                        textFieldFocused = false
                        speech.stopListening()
                    }) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(Color(white: 0.85))
                            )
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(white: 0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color(white: 0.14).opacity(textFieldFocused ? 0.7 : 0.35), lineWidth: 0.5)
                    )
            )
            .frame(maxWidth: 480)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }
}
