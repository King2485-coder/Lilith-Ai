import SwiftUI
import EventKit

// MARK: - Action Manager

final class LilithActionManager: ObservableObject {

    static let shared = LilithActionManager()

    /// Exposed so LilithScheduler can share the same EKEventStore instance.
    static let eventStore = EKEventStore()

    @Published var pending: [LilithAction] = []

    private var store: EKEventStore { LilithActionManager.eventStore }

    private init() { requestPermissions() }

    // MARK: - Permissions

    private func requestPermissions() {
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents    { _, _ in }
            store.requestFullAccessToReminders { _, _ in }
        } else {
            store.requestAccess(to: .event)    { _, _ in }
            store.requestAccess(to: .reminder) { _, _ in }
        }
    }

    // MARK: - Receive / Route

    func receive(_ action: LilithAction) {
        DispatchQueue.main.async {
            self.pending.append(action)
        }
    }

    // MARK: - Approve

    func approve(_ action: LilithAction) {
        executeSmart(action)
        remove(action)
    }

    // MARK: - Reject

    func reject(_ action: LilithAction) { remove(action) }

    private func remove(_ action: LilithAction) {
        pending.removeAll { $0.id == action.id }
    }

    // MARK: - Calendar

    private func createEvent(title: String) {
        let event        = EKEvent(eventStore: store)
        event.title      = title
        event.startDate  = Date().addingTimeInterval(3600)
        event.endDate    = event.startDate.addingTimeInterval(3600)
        event.calendar   = store.defaultCalendarForNewEvents
        try? store.save(event, span: .thisEvent)
    }

    // MARK: - Reminder

    func createReminder(text: String) {
        let reminder      = EKReminder(eventStore: store)
        reminder.title    = text
        reminder.calendar = store.defaultCalendarForNewReminders()
        try? store.save(reminder, commit: true)
    }
}

// MARK: - Approval Overlay

struct LilithApprovalOverlay: View {

    @ObservedObject private var manager = LilithActionManager.shared

    var body: some View {
        VStack {
            Spacer()
            ForEach(manager.pending) { action in
                ApprovalCard(action: action)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .padding(.bottom, 100)
        }
        .animation(.easeInOut(duration: 0.35), value: manager.pending.map(\.id))
    }
}

// MARK: - Approval Card

struct ApprovalCard: View {
    let action: LilithAction

    var body: some View {
        VStack(spacing: 16) {
            Text("Lilith wants to act")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))

            Text(action.text)
                .font(.system(size: 15, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            HStack(spacing: 24) {
                Button {
                    LilithActionManager.shared.reject(action)
                } label: {
                    Text("Reject")
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.horizontal, 22).padding(.vertical, 8)
                        .background(Capsule().fill(Color.red.opacity(0.12)))
                }

                Button {
                    LilithActionManager.shared.approve(action)
                } label: {
                    Text("Approve")
                        .foregroundColor(.green.opacity(0.9))
                        .padding(.horizontal, 22).padding(.vertical, 8)
                        .background(Capsule().fill(Color.green.opacity(0.12)))
                }
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.4))
                .background(
                    RoundedRectangle(cornerRadius: 24).fill(.ultraThinMaterial.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.18))
                )
        )
        .shadow(color: .white.opacity(0.06), radius: 20)
        .padding(.horizontal, 24)
    }
}
