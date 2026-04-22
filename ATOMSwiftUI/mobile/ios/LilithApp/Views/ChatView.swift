import SwiftUI

struct ChatView: View {
    @StateObject private var vm = ChatViewModel()

    var body: some View {
        VStack(spacing: 10) {
            TextField("Other user id", text: $vm.threadUserID)
                .textFieldStyle(.roundedBorder)
            Button("Load Thread") { Task { await vm.loadThread() } }
            List(vm.messages) { message in
                VStack(alignment: .leading) {
                    Text(message.content)
                    Text(message.created_at).font(.caption).foregroundColor(.secondary)
                }
            }
            HStack {
                TextField("Message", text: $vm.messageText)
                    .textFieldStyle(.roundedBorder)
                Button("Send") { Task { await vm.send() } }
            }
        }
        .padding()
    }
}

