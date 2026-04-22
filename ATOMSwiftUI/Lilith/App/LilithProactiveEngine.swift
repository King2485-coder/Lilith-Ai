import SwiftUI
import Combine

// MARK: - Event Model

enum LilithEventType: String, Codable {
    case messageSent
    case appOpened
    case timeTick
}

struct LilithEvent: Identifiable, Codable {
    var id   = UUID()
    let type : LilithEventType
    let text : String?
    let date : Date
}

// MARK: - Memory (Extended)

struct LilithProfile: Codable {
    var favoriteFoods : [String]   = []
    var reminders     : [String]   = []
    var recentMessages: [String]   = []
    var hourlyUsage   : [Int: Int] = [:]   // hour → usage count
}

final class LilithMemoryStore {
    static let shared = LilithMemoryStore()
    private let key = "lilith_profile_v2"

    var profile = LilithProfile()

    private init() { load() }

    func save() {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let p = try? JSONDecoder().decode(LilithProfile.self, from: data) {
            profile = p
        }
    }

    func learn(from text: String) {
        let t = text.lowercased()

        if t.contains("i like") || t.contains("love") {
            profile.favoriteFoods.append(text)
        }
        if t.contains("remind me") {
            profile.reminders.append(text)
        }

        profile.recentMessages.append(text)
        if profile.recentMessages.count > 20 {
            profile.recentMessages.removeFirst()
        }

        let hour = Calendar.current.component(.hour, from: Date())
        profile.hourlyUsage[hour, default: 0] += 1

        save()
    }
}

// MARK: - Context Snapshot

struct LilithContext {
    let now          : Date
    let hour         : Int
    let weekday      : Int
    let lastMessages : [String]
}

enum LilithContextProvider {
    static func current() -> LilithContext {
        let now = Date()
        let cal = Calendar.current
        return LilithContext(
            now: now,
            hour: cal.component(.hour, from: now),
            weekday: cal.component(.weekday, from: now),
            lastMessages: LilithMemoryStore.shared.profile.recentMessages
        )
    }
}

// MARK: - Prediction Engine

struct LilithPrediction: Identifiable {
    let id   = UUID()
    let text : String
    let score: Double
}

enum LilithPredictor {

    static func predict(context: LilithContext) -> [LilithPrediction] {

        let profile = LilithMemoryStore.shared.profile
        var results: [LilithPrediction] = []

        // Evening dinner suggestion
        if (17...21).contains(context.hour),
           let lastFood = profile.favoriteFoods.last {
            results.append(.init(
                text: "It's evening — want \(lastFood) again tonight?",
                score: 0.9
            ))
        }

        // Reminder resurfacing
        if let reminder = profile.reminders.last {
            results.append(.init(
                text: "Reminder: \(reminder)",
                score: 0.8
            ))
        }

        // Habit loop
        let usage = profile.hourlyUsage[context.hour] ?? 0
        if usage > 5 {
            results.append(.init(
                text: "You usually check Lilith around now — anything you need?",
                score: 0.6
            ))
        }

        // Conversation continuation
        if let last = context.lastMessages.last {
            results.append(.init(
                text: "Earlier you mentioned: \"\(last)\" — continue?",
                score: 0.5
            ))
        }

        return results.sorted { $0.score > $1.score }
    }
}

// MARK: - Proactive Engine

final class LilithProactiveEngine: ObservableObject {

    static let shared = LilithProactiveEngine()

    @Published var suggestions: [LilithPrediction] = []

    private var timer: AnyCancellable?

    private init() {}

    func start() {
        guard timer == nil else { return }
        timer = Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
        tick()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let context = LilithContextProvider.current()
        let preds   = LilithPredictor.predict(context: context)
        suggestions = Array(preds.prefix(2))
    }
}

// MARK: - Suggestion Overlay (drop into Void)

struct LilithSuggestionOverlay: View {

    @ObservedObject private var engine = LilithProactiveEngine.shared

    var body: some View {
        VStack(spacing: 12) {
            ForEach(engine.suggestions) { suggestion in
                SuggestionCard(text: suggestion.text)
                    .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
        .animation(.easeOut(duration: 0.4), value: engine.suggestions.map(\.id))
        .onAppear {
            LilithProactiveEngine.shared.start()
        }
    }
}

struct SuggestionCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.black.opacity(0.35))
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(.ultraThinMaterial.opacity(0.2))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.15))
                    )
            )
            .shadow(color: .white.opacity(0.1), radius: 20)
            .padding(.horizontal, 28)
    }
}

// MARK: - Brain API

enum LilithBrain {

    static func userSent(_ text: String) {
        LilithMemoryStore.shared.learn(from: text)
    }

    static func appOpened() {
        let hour = Calendar.current.component(.hour, from: Date())
        LilithMemoryStore.shared.profile.hourlyUsage[hour, default: 0] += 1
        LilithMemoryStore.shared.save()
    }
}
