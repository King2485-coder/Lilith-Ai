import Foundation
import UserNotifications
import Combine

// MARK: - Action Types

enum LilithActionType: String, Codable {
    case suggest
    case remind
    case checkin
    case notify
    case createCalendar  // creates a calendar event (requires approval)
    case createReminder  // creates a reminder (requires approval)
    case askUser         // generic confirmation required
    case planDay         // generates + applies a full-day GPT plan
}

struct LilithAction: Codable, Identifiable {
    let id              : String
    let type            : LilithActionType
    let text            : String
    let confidence      : Double
    let cooldownSeconds : Int?
}

struct LilithPlanResponse: Codable {
    let actions: [LilithAction]
}

// MARK: - Rate Limiter (device-side safety)

final class LilithRateLimiter {
    static let shared = LilithRateLimiter()
    private var lastFired: [String: Date] = [:]
    private init() {}

    func allow(_ action: LilithAction) -> Bool {
        let key      = action.type.rawValue + "|" + action.text
        let now      = Date()
        let cooldown = TimeInterval(action.cooldownSeconds ?? 900)
        if let last = lastFired[key], now.timeIntervalSince(last) < cooldown { return false }
        lastFired[key] = now
        return true
    }
}

// MARK: - Autonomous GPT Engine

final class LilithAutonomousGPT: ObservableObject {

    static let shared = LilithAutonomousGPT()

    private var timer  : AnyCancellable?
    private let base   = "http://127.0.0.1:8000"

    private init() {}

    func start() {
        requestNotificationPermission()
        guard timer == nil else { return }
        timer = Timer.publish(every: 600, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.cycle() }
        cycle()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Core Cycle

    private func cycle() {
        let ctx = LilithContextProvider.current()
        let mem = LilithMemoryStore.shared.profile
        requestPlan(context: ctx, memory: mem) { [weak self] plan in
            self?.handle(plan: plan)
        }
    }

    // MARK: - Request Plan from GPT

    private func requestPlan(context: LilithContext,
                             memory: LilithProfile,
                             completion: @escaping (LilithPlanResponse) -> Void) {
        guard let url = URL(string: "\(base)/api/plan") else { return }
        var req = URLRequest(url: url, timeoutInterval: 12)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "context": [
                "hour"          : context.hour,
                "weekday"       : context.weekday,
                "recentMessages": Array(context.lastMessages.suffix(5))
            ],
            "memory": [
                "favoriteFoods" : Array(memory.favoriteFoods.suffix(5)),
                "reminders"     : Array(memory.reminders.suffix(5))
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let plan = try? JSONDecoder().decode(LilithPlanResponse.self, from: data)
            else { return }
            DispatchQueue.main.async { completion(plan) }
        }.resume()
    }

    // MARK: - Handle Plan

    private func handle(plan: LilithPlanResponse) {
        for action in plan.actions {
            guard action.confidence >= 0.55                 else { continue }
            guard LilithRateLimiter.shared.allow(action)    else { continue }

            switch action.type {
            case .suggest, .checkin:
                postToUI(action.text)
            case .remind, .notify:
                sendNotification(action.text)
                postToUI(action.text)
            case .askUser, .createCalendar, .createReminder:
                LilithActionManager.shared.receive(action)
            case .planDay:
                LilithDayPlanner.shared.generateAndApply(for: Date())
            }
        }
    }

    // MARK: - Actions

    private func postToUI(_ text: String) {
        NotificationCenter.default.post(name: .lilithAction, object: text)
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func sendNotification(_ text: String) {
        let content       = UNMutableNotificationContent()
        content.title     = "Lilith"
        content.body      = text
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        )
    }
}
