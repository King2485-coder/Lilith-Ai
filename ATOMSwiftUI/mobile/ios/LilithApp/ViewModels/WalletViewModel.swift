import Foundation

@MainActor
final class WalletViewModel: ObservableObject {
    @Published var balance: PaymentBalance?
    @Published var receiverID: String = ""
    @Published var amount: String = ""
    @Published var error: String?

    private let service = PaymentService()

    func loadBalance() async {
        do {
            balance = try await service.fetchBalance()
        } catch {
            error = String(describing: error)
        }
    }

    func sendPayment() async {
        guard let value = Double(amount), !receiverID.isEmpty else { return }
        do {
            let intent = try await service.createPayment(receiverID: receiverID, amount: value)
            _ = try await service.confirmPayment(intentID: intent.id)
            await loadBalance()
        } catch {
            error = String(describing: error)
        }
    }
}

