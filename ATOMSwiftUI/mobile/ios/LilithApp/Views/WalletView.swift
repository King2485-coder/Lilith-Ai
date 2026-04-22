import SwiftUI

struct WalletView: View {
    @StateObject private var vm = WalletViewModel()

    var body: some View {
        VStack(spacing: 10) {
            if let balance = vm.balance {
                Text("USD: \(balance.fiat_balance, specifier: "%.2f")")
                Text("USDC: \(balance.usdc_balance, specifier: "%.2f")")
            } else {
                Text("No balance loaded")
            }
            TextField("Receiver user id", text: $vm.receiverID)
                .textFieldStyle(.roundedBorder)
            TextField("Amount", text: $vm.amount)
                .textFieldStyle(.roundedBorder)
            Button("Send Payment") { Task { await vm.sendPayment() } }
                .buttonStyle(.borderedProminent)
            Button("Refresh Balance") { Task { await vm.loadBalance() } }
            if let error = vm.error {
                Text(error).foregroundColor(.red).font(.caption)
            }
        }
        .padding()
        .task { await vm.loadBalance() }
    }
}

