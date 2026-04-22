import Foundation

struct CreateIntentPayload: Encodable {
    let receiver_id: String
    let amount: Double
    let currency: String
    let kind: String
}

struct ConfirmIntentPayload: Encodable {
    let intent_id: String
}

final class PaymentService {
    private let api = APIClient.shared

    func fetchBalance() async throws -> PaymentBalance {
        try await api.get("/api/v1/payments/balance")
    }

    func createPayment(receiverID: String, amount: Double, currency: String = "USD", kind: String = "tip") async throws -> PaymentIntent {
        try await api.post(
            "/api/v1/payments/create-intent",
            body: CreateIntentPayload(receiver_id: receiverID, amount: amount, currency: currency, kind: kind)
        )
    }

    func confirmPayment(intentID: String) async throws -> PaymentIntent {
        try await api.post("/api/v1/payments/confirm", body: ConfirmIntentPayload(intent_id: intentID))
    }
}

