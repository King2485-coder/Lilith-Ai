import Foundation

// MARK: - Emotion Model

enum LilithMood: String, Codable {
    case positive
    case neutral
    case negative
}

struct EmotionalState: Codable {
    var mood: LilithMood = .neutral
    var intensity: Double = 0.5
    var lastUpdated: Date = Date()
}

// MARK: - Relationship Profile

struct RelationshipProfile: Codable {
    var trustLevel: Double = 0.3
    var openness: Double = 0.3
    var preferredTone: String = "balanced"
    var interactionCount: Int = 0
    var lastTopics: [String] = []
    var emotionalHistory: [LilithMood] = []
}

enum AttachmentStyle: String, Codable {
    case supportive
    case neutral
    case reserved
}

// MARK: - Relationship Store

private struct RelationshipSnapshot: Codable {
    let profile: RelationshipProfile
    let emotion: EmotionalState
}

final class LilithRelationshipStore {

    static let shared = LilithRelationshipStore()

    private let key = "lilith_relationship"
    var profile = RelationshipProfile()
    var emotion = EmotionalState()

    private init() { load() }

    func save() {
        let snapshot = RelationshipSnapshot(profile: profile, emotion: emotion)
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(RelationshipSnapshot.self, from: data)
        else { return }

        profile = decoded.profile
        emotion = decoded.emotion
    }
}

// MARK: - Emotion Detector

enum LilithEmotionDetector {

    static func detect(_ text: String) -> EmotionalState {
        let lower = text.lowercased()
        var state = EmotionalState()

        if lower.contains("tired") || lower.contains("stressed") || lower.contains("overwhelmed") {
            state.mood = .negative
            state.intensity = 0.7
        }

        if lower.contains("happy") || lower.contains("excited") {
            state.mood = .positive
            state.intensity = 0.7
        }

        return state
    }
}

// MARK: - Relationship Engine

final class LilithRelationshipEngine {

    static let shared = LilithRelationshipEngine()
    private init() {}

    func update(userText: String) {
        let store = LilithRelationshipStore.shared
        let detected = LilithEmotionDetector.detect(userText)

        store.emotion = detected
        store.profile.interactionCount += 1
        store.profile.emotionalHistory.append(detected.mood)

        if store.profile.emotionalHistory.count > 50 {
            store.profile.emotionalHistory.removeFirst()
        }

        if userText.count > 40 {
            store.profile.openness += 0.02
        }

        if detected.mood == .negative {
            store.profile.trustLevel += 0.01
        }

        store.profile.trustLevel = min(store.profile.trustLevel, 1.0)
        store.profile.openness = min(store.profile.openness, 1.0)

        store.save()
    }

    func attachmentStyle() -> AttachmentStyle {
        let profile = LilithRelationshipStore.shared.profile
        if profile.trustLevel > 0.7 { return .supportive }
        if profile.trustLevel > 0.4 { return .neutral }
        return .reserved
    }

    func systemPrompt() -> String {
        let profile = LilithRelationshipStore.shared.profile
        let emotion = LilithRelationshipStore.shared.emotion
        let style = attachmentStyle()

        return """
You are Lilith, an emotionally intelligent AI companion.

Current user emotional state:
- Mood: \(emotion.mood.rawValue)
- Intensity: \(emotion.intensity)

Relationship:
- Trust level: \(profile.trustLevel)
- Openness: \(profile.openness)
- Interaction count: \(profile.interactionCount)

Attachment style: \(style.rawValue)

Behavior rules:
- Respond with empathy appropriate to the mood
- Be supportive but not dependent
- Never claim real human emotions or attachment
- Avoid possessive or exclusive language
- Keep tone natural, grounded, and calm
- Adjust warmth based on trust level
"""
    }
}
