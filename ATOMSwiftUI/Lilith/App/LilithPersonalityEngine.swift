import Foundation

// MARK: - Personality Model

struct LilithPersonality: Codable {
    var tone: String = "calm"
    var warmth: Double = 0.5
    var humor: Double = 0.2
    var directness: Double = 0.6
    var curiosity: Double = 0.5
    var userMoodEstimate: String = "neutral"
}

// MARK: - Personality Store

final class LilithPersonalityStore {

    static let shared = LilithPersonalityStore()

    private let key = "lilith_personality"
    var personality = LilithPersonality()

    private init() { load() }

    func save() {
        if let data = try? JSONEncoder().encode(personality) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(LilithPersonality.self, from: data) {
            personality = decoded
        }
    }
}

// MARK: - Personality Engine

final class LilithPersonalityEngine {

    static let shared = LilithPersonalityEngine()
    private init() {}

    func learn(from userText: String) {
        var p = LilithPersonalityStore.shared.personality
        let text = userText.lowercased()

        if text.contains("tired") || text.contains("stressed") {
            p.warmth += 0.05
            p.userMoodEstimate = "low"
        }

        if text.contains("excited") || text.contains("happy") {
            p.humor += 0.05
            p.userMoodEstimate = "high"
        }

        if text.contains("just tell me") {
            p.directness += 0.05
        }

        if text.contains("why") || text.contains("how") {
            p.curiosity += 0.05
        }

        p.warmth = min(max(p.warmth, 0.0), 1.0)
        p.humor = min(max(p.humor, 0.0), 1.0)
        p.directness = min(max(p.directness, 0.0), 1.0)
        p.curiosity = min(max(p.curiosity, 0.0), 1.0)

        LilithPersonalityStore.shared.personality = p
        LilithPersonalityStore.shared.save()
    }

    func systemPrompt() -> String {
        let p = LilithPersonalityStore.shared.personality
        return """
You are Lilith, an evolving AI companion.

Personality:
- Tone: \(p.tone)
- Warmth: \(p.warmth)
- Humor: \(p.humor)
- Directness: \(p.directness)
- Curiosity: \(p.curiosity)

User mood estimate: \(p.userMoodEstimate)

Behavior rules:
- Adapt your tone naturally based on the user
- Be consistent (you are the same person over time)
- Do not sound robotic
- Do not explain your personality
- Speak like a real human companion
"""
    }
}
