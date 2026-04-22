import Foundation
import UserNotifications
import Combine

// MARK: - Notification Name

extension Notification.Name {
    static let lilithAction = Notification.Name("lilithAction")
}

// MARK: - Autonomous Engine

final class LilithAutonomousEngine: ObservableObject {

    static let shared = LilithAutonomousEngine()

    private var timer: AnyCancellable?

    private init() {}

    func start() {
        requestNotificationPermission()
        guard timer == nil else { return }
        timer = Timer.publish(every: 900, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.runCycle() }
        runCycle()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Core Loop

    private func runCycle() {
        let context = LilithContextProvider.current()
        let memory  = LilithMemoryStore.shared.profile
        decide(context: context, memory: memory)
    }

    // MARK: - Decision Engine

    private func decide(context: LilithContext, memory: LilithProfile) {
        let hour = context.hour

        // Evening dinner suggestion
        if (17...20).contains(hour), let lastFood = memory.favoriteFoods.last {
            trigger(text: "You usually eat around now. Want \(lastFood)?", type: .suggestion)
        }

        // Reminder check
        if let reminder = memory.reminders.last {
            trigger(text: "Don't forget: \(reminder)", type: .reminder)
        }

        // Habit loop
        let usage = memory.hourlyUsage[hour] ?? 0
        if usage > 5 {
            trigger(text: "You're usually active right now. Need anything?", type: .checkin)
        }
    }

    // MARK: - Action System

    enum ActionType { case suggestion, reminder, checkin }

    private func trigger(text: String, type: ActionType) {
        sendNotification(text: text)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .lilithAction, object: text)
        }
    }

    // MARK: - Push Notifications

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func sendNotification(text: String) {
        let content       = UNMutableNotificationContent()
        content.title     = "Lilith"
        content.body      = text
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
