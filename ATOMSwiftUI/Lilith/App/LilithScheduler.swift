import Foundation
import EventKit

// MARK: - Time Parser

struct ParsedTime {
    let date      : Date
    let confidence: Double
}

enum LilithTimeParser {

    static func parse(_ text: String) -> ParsedTime? {

        // 1. NSDataDetector (handles "tomorrow at 7", "Friday 3pm", ISO dates, etc.)
        let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.date.rawValue
        )
        if let match = detector?.firstMatch(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text)
        ), let date = match.date {
            return ParsedTime(date: date, confidence: 0.9)
        }

        // 2. Fallback keyword rules
        let lower = text.lowercased()
        let now   = Date()
        let cal   = Calendar.current

        if lower.contains("tomorrow") {
            let d = cal.date(byAdding: .day, value: 1, to: now)!
            return ParsedTime(date: d, confidence: 0.6)
        }

        if lower.contains("tonight") {
            var c = cal.dateComponents([.year, .month, .day], from: now)
            c.hour   = 19
            c.minute = 0
            let d = cal.date(from: c)!
            return ParsedTime(date: d, confidence: 0.7)
        }

        if lower.contains("next week") {
            let d = cal.date(byAdding: .weekOfYear, value: 1, to: now)!
            return ParsedTime(date: d, confidence: 0.5)
        }

        return nil
    }
}

// MARK: - Scheduler

final class LilithScheduler {

    static let shared = LilithScheduler()

    // Uses the same EKEventStore owned by LilithActionManager to avoid double-access
    private var store: EKEventStore { LilithActionManager.eventStore }

    private init() {}

    // MARK: - Smart Schedule

    func schedule(from text: String) {
        guard let parsed = LilithTimeParser.parse(text) else { return }
        let start = parsed.date
        let end   = start.addingTimeInterval(3600)

        guard !hasConflict(start: start, end: end) else {
            // Surface conflict as a proactive message
            NotificationCenter.default.post(
                name: .lilithAction,
                object: "There's already something on your calendar then. Want me to pick another time?"
            )
            return
        }

        let event        = EKEvent(eventStore: store)
        event.title      = extractTitle(from: text)
        event.startDate  = start
        event.endDate    = end
        event.calendar   = store.defaultCalendarForNewEvents
        try? store.save(event, span: .thisEvent)
    }

    // MARK: - Conflict Detection

    func hasConflict(start: Date, end: Date) -> Bool {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return !store.events(matching: predicate).isEmpty
    }

    // MARK: - Title Extraction

    func extractTitle(from text: String) -> String {
        let lower = text.lowercased()
        // Strip common prefixes like "schedule dinner for …" / "add … for …"
        for prefix in ["schedule ", "add ", "create "] {
            if lower.hasPrefix(prefix) {
                return String(text.dropFirst(prefix.count)).capitalized
            }
        }
        if let range = lower.range(of: " for ") {
            return String(text[range.upperBound...]).capitalized
        }
        return text.capitalized
    }
}

// MARK: - LilithActionManager extension (smart execution)

extension LilithActionManager {

    /// Routes calendar actions through the advanced GPT-powered scheduler.
    func executeSmart(_ action: LilithAction) {
        switch action.type {
        case .createCalendar:
            LilithAdvancedScheduler.shared.handleRequest(action.text)
        case .createReminder:
            createReminder(text: action.text)
        case .planDay:
            LilithDayPlanner.shared.generateAndApply(for: Date())
        default:
            break
        }
    }
}
