import Foundation
import EventKit
import Combine

// MARK: - Realtime Engine

final class LilithRealtimeEngine: ObservableObject {

    static let shared = LilithRealtimeEngine()
    private var store: EKEventStore { LilithActionManager.eventStore }
    private var timer: AnyCancellable?

    @Published var liveUpdates: [String] = []

    private init() {}

    // MARK: - Start

    func start() {
        // Evaluate immediately, then every 60 seconds
        evaluate()
        timer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.evaluate() }
    }

    // MARK: - Core Thinking Loop

    private func evaluate() {
        let now    = Date()
        let events = fetchTodayEvents()

        guard let current = events.first(where: {
            $0.startDate <= now && $0.endDate >= now
        }) else {
            handleIdleTime()
            return
        }

        // Detect if user is 5+ minutes late to an event
        if now > current.startDate.addingTimeInterval(300) {
            adjustSchedule(for: current)
        }
    }

    // MARK: - Idle Time

    private func handleIdleTime() {
        publish("You have free time. Want me to suggest a task?")
    }

    // MARK: - Late Detection & Adjustment

    private func adjustSchedule(for event: EKEvent) {
        let delay   = Date().timeIntervalSince(event.startDate)
        let title   = event.title ?? "your event"
        publish("You're running late for \(title). Adjusting your schedule...")
        shiftRemainingEvents(by: delay)
    }

    // MARK: - Shift Future Events

    private func shiftRemainingEvents(by delay: TimeInterval) {
        let now    = Date()
        let events = fetchTodayEvents()

        for event in events where event.startDate > now {
            event.startDate = event.startDate.addingTimeInterval(delay)
            event.endDate   = event.endDate.addingTimeInterval(delay)
            try? store.save(event, span: .thisEvent)
        }

        publish("Schedule updated to match your pace.")
    }

    // MARK: - Fetch Today

    private func fetchTodayEvents() -> [EKEvent] {
        let start = Calendar.current.startOfDay(for: Date())
        let end   = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
    }

    // MARK: - Publish

    private func publish(_ text: String) {
        DispatchQueue.main.async {
            self.liveUpdates.append(text)
            NotificationCenter.default.post(name: .lilithRealtimeUpdate, object: text)
        }
    }
}

// MARK: - Notification Name

extension Notification.Name {
    static let lilithRealtimeUpdate = Notification.Name("lilithRealtimeUpdate")
}
