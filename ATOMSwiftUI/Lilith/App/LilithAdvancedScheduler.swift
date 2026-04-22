import Foundation
import EventKit

// MARK: - GPT Parsed Event Model

struct PlannedEvent: Codable, Identifiable {
    let id             : String
    let title          : String
    let start          : Date
    let end            : Date
    let isRecurring    : Bool
    let recurrenceRule : String?

    private enum CodingKeys: String, CodingKey {
        case id, title, start, end, isRecurring, recurrenceRule
    }

    init(from decoder: Decoder) throws {
        let c       = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(String.self, forKey: .id)
        title       = try c.decode(String.self, forKey: .title)
        isRecurring = try c.decodeIfPresent(Bool.self,   forKey: .isRecurring)    ?? false
        recurrenceRule = try c.decodeIfPresent(String.self, forKey: .recurrenceRule)

        // Backend returns ISO-8601 strings
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startStr = try c.decode(String.self, forKey: .start)
        let endStr   = try c.decode(String.self, forKey: .end)
        start = iso.date(from: startStr) ?? Date()
        end   = iso.date(from: endStr)   ?? Date().addingTimeInterval(3600)
    }
}

// MARK: - Scheduling AI Service

final class LilithSchedulingAI {

    static let shared = LilithSchedulingAI()
    private let base  = "http://127.0.0.1:8000"
    private init() {}

    func parse(text: String, completion: @escaping ([PlannedEvent]) -> Void) {
        guard let url = URL(string: "\(base)/api/schedule") else { return }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let events = try? JSONDecoder().decode([PlannedEvent].self, from: data)
            else { return }
            DispatchQueue.main.async { completion(events) }
        }.resume()
    }
}

// MARK: - Advanced Scheduler

final class LilithAdvancedScheduler {

    static let shared = LilithAdvancedScheduler()
    private var store: EKEventStore { LilithActionManager.eventStore }
    private init() {}

    // MARK: - Entry Point

    func handleRequest(_ text: String) {
        LilithSchedulingAI.shared.parse(text: text) { events in
            for event in events { self.schedule(event) }
        }
    }

    // MARK: - Schedule Single Event

    private func schedule(_ planned: PlannedEvent) {
        var start = planned.start
        var end   = planned.end

        // Conflict resolution — slide forward up to 10 hours
        if hasConflict(start: start, end: end) {
            if let slot = findNextAvailableSlot(from: start) {
                let duration = planned.end.timeIntervalSince(planned.start)
                start = slot
                end   = slot.addingTimeInterval(duration)
            }
        }

        let event        = EKEvent(eventStore: store)
        event.title      = planned.title
        event.startDate  = start
        event.endDate    = end
        event.calendar   = store.defaultCalendarForNewEvents

        if planned.isRecurring, let rule = planned.recurrenceRule {
            event.recurrenceRules = [buildRecurrence(rule)]
        }

        try? store.save(event, span: .thisEvent)
    }

    // MARK: - Conflict Detection

    func hasConflict(start: Date, end: Date) -> Bool {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return !store.events(matching: predicate).isEmpty
    }

    // MARK: - Find Open Slot

    private func findNextAvailableSlot(from start: Date) -> Date? {
        var candidate = start
        for _ in 0..<10 {
            let candidateEnd = candidate.addingTimeInterval(3600)
            if !hasConflict(start: candidate, end: candidateEnd) { return candidate }
            candidate = Calendar.current.date(byAdding: .hour, value: 1, to: candidate)!
        }
        return nil
    }

    // MARK: - Recurrence Rule Builder

    private func buildRecurrence(_ rule: String) -> EKRecurrenceRule {
        switch rule.lowercased() {
        case "weekly":
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case "monthly":
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        default: // "daily" + fallback
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        }
    }
}
