import SwiftUI

// MARK: - Plans & Packages (mirrors web PLANS / CREDIT_PACKAGES)

private struct Plan: Identifiable {
    let id: String
    let name: String
    let price: Double
    let creditsPerMonth: Double?   // nil = unlimited
    let popular: Bool
}

private let kPlans: [Plan] = [
    Plan(id: "free",       name: "Free",       price: 0,  creditsPerMonth: 10,  popular: false),
    Plan(id: "core",       name: "Core",       price: 20, creditsPerMonth: 25,  popular: true),
    Plan(id: "pro",        name: "Pro",        price: 40, creditsPerMonth: 50,  popular: false),
    Plan(id: "enterprise", name: "Enterprise", price: 99, creditsPerMonth: nil, popular: false),
]

private struct CreditPackage: Identifiable {
    let id: String
    let name: String
    let credits: Double
    let price: Double
}

private let kCreditPackages: [CreditPackage] = [
    CreditPackage(id: "small",  name: "Small",  credits: 10,  price: 5),
    CreditPackage(id: "medium", name: "Medium", credits: 25,  price: 10),
    CreditPackage(id: "large",  name: "Large",  credits: 50,  price: 18),
    CreditPackage(id: "xlarge", name: "XL",     credits: 100, price: 30),
]

// MARK: - SubscriptionSheet

struct SubscriptionSheet: View {
    @EnvironmentObject private var authStore: AuthStore
    var currentPlan: String
    var credits: Double
    var isSuperAdmin: Bool
    var onDismiss: () -> Void
    var onPurchaseComplete: () -> Void

    @State private var activeTab: SheetTab = .plans
    @State private var loadingId: String?
    @State private var errorMessage: String?

    private enum SheetTab: String, CaseIterable {
        case plans = "Plans"
        case credits = "Buy Credits"
    }

    private let apiClient = APIClient()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerBadge
                tabPicker
                Divider().background(Color.white.opacity(0.1))
                content
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.04).ignoresSafeArea())
            .navigationTitle("Upgrade Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: onDismiss)
                        .foregroundStyle(LilithTheme.accentA)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerBadge: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Current Plan: \(currentPlan.capitalized)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if isSuperAdmin {
                    Text("Unlimited credits (Super Admin)")
                        .font(.caption)
                        .foregroundStyle(Color.purple)
                } else {
                    Text(String(format: "Credits: $%.2f", credits))
                        .font(.caption)
                        .foregroundStyle(LilithTheme.textSecondary)
                }
            }
            Spacer()
            if isSuperAdmin {
                Label("UNLIMITED", systemImage: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(SheetTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation { activeTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .foregroundStyle(activeTab == tab ? LilithTheme.accentA : .gray)
                        .overlay(alignment: .bottom) {
                            if activeTab == tab {
                                Rectangle()
                                    .fill(LilithTheme.accentA)
                                    .frame(height: 2)
                            }
                        }
                }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        ScrollView {
            if activeTab == .plans {
                plansGrid
            } else {
                creditsGrid
            }

            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
            }
        }
    }

    // MARK: - Plans Grid

    private var plansGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(kPlans) { plan in
                planCard(plan)
            }
        }
        .padding(16)
    }

    private func planCard(_ plan: Plan) -> some View {
        let isCurrentPlan = currentPlan.lowercased() == plan.id
        let isFree = plan.id == "free"

        return ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(plan.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("$\(Int(plan.price))")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                    Text("/mo")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }

                if let c = plan.creditsPerMonth {
                    Text("$\(Int(c)) credits/mo")
                        .font(.caption)
                        .foregroundStyle(.gray)
                } else {
                    Text("Unlimited credits")
                        .font(.caption)
                        .foregroundStyle(Color.purple)
                }

                Button {
                    guard !isFree && !isCurrentPlan else { return }
                    Task { await subscribe(planId: plan.id) }
                } label: {
                    Group {
                        if loadingId == plan.id {
                            ProgressView().tint(.white)
                        } else if isCurrentPlan {
                            Text("Current")
                        } else if isFree {
                            Text("Free Tier")
                        } else {
                            Text("Subscribe")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(isCurrentPlan ? .green : (isFree ? Color.gray.opacity(0.3) : LilithTheme.accentA))
                .disabled(isFree || isCurrentPlan || loadingId != nil)
            }
            .padding(14)
            .background(
                plan.popular
                    ? LilithTheme.accentA.opacity(0.07)
                    : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        plan.popular ? LilithTheme.accentA.opacity(0.4) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )

            if plan.popular {
                Text("POPULAR")
                    .font(.system(size: 9, weight: .black))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(LilithTheme.accentA)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
                    .offset(y: -12)
            }
        }
        .padding(.top, plan.popular ? 12 : 0)
    }

    // MARK: - Credits Grid

    private var creditsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(kCreditPackages) { pkg in
                creditCard(pkg)
            }
        }
        .padding(16)
    }

    private func creditCard(_ pkg: CreditPackage) -> some View {
        Button {
            Task { await buyCredits(packageId: pkg.id) }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(pkg.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    if loadingId == pkg.id {
                        ProgressView().scaleEffect(0.8).tint(.white)
                    }
                }

                Text("$\(Int(pkg.credits))")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(LilithTheme.accentA)
                + Text(" credits")
                    .font(.caption)
                    .foregroundStyle(.gray)

                Text("$\(Int(pkg.price)) USD")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(14)
            .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .disabled(loadingId != nil)
    }

    // MARK: - API

    private func subscribe(planId: String) async {
        loadingId = planId
        errorMessage = nil
        defer { loadingId = nil }
        do {
            guard let token = authStore.token else { return }
            let originURL = APIConfig.baseURLString
            let result: CheckoutResponse = try await apiClient.request(
                "/checkout/subscription", method: "POST",
                body: SubscriptionCheckoutPayload(planId: planId, originUrl: originURL),
                token: token
            )
            if let url = URL(string: result.checkoutUrl) {
                await UIApplication.shared.open(url)
                onPurchaseComplete()
                onDismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func buyCredits(packageId: String) async {
        loadingId = packageId
        errorMessage = nil
        defer { loadingId = nil }
        do {
            guard let token = authStore.token else { return }
            let originURL = APIConfig.baseURLString
            let result: CheckoutResponse = try await apiClient.request(
                "/checkout/credits", method: "POST",
                body: CreditsCheckoutPayload(packageId: packageId, originUrl: originURL),
                token: token
            )
            if let url = URL(string: result.checkoutUrl) {
                await UIApplication.shared.open(url)
                onPurchaseComplete()
                onDismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
