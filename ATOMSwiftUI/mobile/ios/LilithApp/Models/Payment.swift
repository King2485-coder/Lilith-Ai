import Foundation

struct PaymentBalance: Codable {
    let fiat_balance: Double
    let usdc_balance: Double
}

struct PaymentIntent: Codable, Identifiable {
    let id: String
    let status: String
    let amount: Double?
    let currency: String?
    let receiver_id: String?
    let kind: String?
    let created_at: String?
}

struct PaymentHistoryResponse: Codable {
    let items: [PaymentIntent]
}

