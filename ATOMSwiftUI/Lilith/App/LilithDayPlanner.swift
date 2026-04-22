import Foundation
import EventKit

// MARK: - Day Block Model

struct DayBlock: Codable, Identifiable {
    let id       : String
    let title    : String
    let start    : Date
    let end      : Date
    let priority : Int

    private enum CodingKeys: String, CodingKey {
        case id, title, start, end, priority
    }

    init(from decoder: Decoder) throws {
        let c    = try decoder.container(keyedBy: CodingKeys.self)
        id       = try c.decode(String.self, forKey: .id)
        title    = try c.decode(String.self, forKey: .title)
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 1

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startStr = try c.decode(String.self, forKey: .start)
        let endStr   = try c.decode(String.self, forKey: .end)
        start = iso.date(from: startStr) ?? Date()
        end   = iso.date(from: endStr)   ?? Date().addingTimeInterval(3600)
    }
}

// MARK: - Day Planner Service

final class LilithDayPlanner {

    static let shared = LilithDayPlanner()
    private let base  = "http://127.0.0.1:8000"
    private var store : EKEventStore { LilithActionManager.eventStore }
    private init() {}

    // MARK: - Generate Plan

    /// Fetches existing events, sends them to GPT, returns a full day plan.
    func generatePlan(for date: Date, completion: @escaping ([DayBlock]) -> Void) {
        let existing = fetchExistingEvents(for: date).map { ev -> [String: String] in
            let iso = ISO8601DateFormatter()
            return [
                "title": ev.title ?? "",
                "start": iso.string(from: ev.startDate),
                "end":   iso.string(from: ev.endDate)
            ]
        }

        guard let url = URL(string: "\(base)/api/dayplan") else { return }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let iso = ISO8601DateFormatter()
        let body: [String: Any] = [
            "date":   iso.string(from: date),
            "events": existing
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let blocks = try? JSONDecoder().decode([DayBlock].self, from: data)
            else { return }
            DispatchQueue.main.async { completion(blocks) }
        }.resume()
    }

    // MARK: - Apply Plan

    /// Schedules each block, resolving conflicts by sliding forward.
    func applyPlan(_ blocks: [DayBlock]) {
        let sorted = blocks.sorted { $0.priority < $1.priority }
        for block in sorted { scheduleBlock(block) }
    }

    // MARK: - Generate + Auto-Apply

    func generateAndApply(for date: Date) {
        generatePlan(for: date) { [weak self] blocks in
            self?.applyPlan(blocks)
            NotificationCenter.default.post(
                name: .lilithAction,
                object: nil,
                userInfo: ["text": "Day plan applied — \(blocks.count) blocks scheduled."]
            )
        }
    }

    // MARK: - Private: Schedule Single Block

    private func scheduleBlock(_ block: DayBlock) {
        let duration = block.end.timeIntervalSince(block.start)
        var start    = block.start
        var end      = block.end

        if hasConflict(start: start, end: end) {
            if let slot = findNextSlot(duration: duration, after: start) {
                start = slot
                end   = slot.addingTimeInterval(duration)
            }
        }

        let event       = EKEvent(eventStore: store)
        event.title     = block.title
        event.startDate = start
        event.endDate   = end
        event.calendar  = store.defaultCalendarForNewEvents
        try? store.save(event, span: .thisEvent)
    }

    // MARK: - Private: Find Open Slot

    private func findNextSlot(duration: TimeInterval, after base: Date) -> Date? {
        var candidate = base
        for _ in 0..<12 {
            if !hasConflict(start: candidate, end: candidate.addingTimeInterval(duration)) {
                return candidate
            }
            candidate = Calendar.current.date(byAdding: .hour, value: 1, to: candidate)!
        }
        return nil
    }

    // MARK: - Private: Conflict Detection

    private func hasConflict(start: Date, end: Date) -> Bool {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return !store.events(matching: predicate).isEmpty
    }

    // MARK: - Private: Fetch Existing Events

    private func fetchExistingEvents(for date: Date) -> [EKEvent] {
        let dayStart = Calendar.current.startOfDay(for: date)
        let dayEnd   = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!
        let predicate = store.predicateForEvents(withStart: dayStart, end: dayEnd, calendars: nil)
        return store.events(matching: predicate)
    }
}
