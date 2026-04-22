import SwiftUI

struct ToolRunnerView: View {
    @StateObject private var vm = ToolViewModel()

    var body: some View {
        VStack(spacing: 10) {
            TextField("Tool name", text: $vm.toolName)
                .textFieldStyle(.roundedBorder)
            TextField("Input", text: $vm.inputText)
                .textFieldStyle(.roundedBorder)
            Button("Run Tool") { Task { await vm.run() } }
                .buttonStyle(.borderedProminent)
            ScrollView {
                Text(vm.resultText).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error = vm.error {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
        .padding()
    }
}

