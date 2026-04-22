import Foundation
import AppIntents
import UIKit

// MARK: - Workflow Model

struct LilithWorkflow: Codable, Identifiable {
    let id: String
    let steps: [LilithStep]
}

struct LilithStep: Codable, Identifiable {
    let id: String
    let type: String
    let payload: [String: String]
}

// MARK: - Workflow Engine

final class LilithWorkflowEngine {

    static let shared = LilithWorkflowEngine()
    private let base = "http://127.0.0.1:8000"

    private init() {}

    // MARK: - Run Workflow

    func run(_ workflow: LilithWorkflow) {
        executeStep(workflow.steps, index: 0)
    }

    // MARK: - Generate From Text (Backend)

    func generateAndRun(from text: String) {
        guard let url = URL(string: "\(base)/api/workflow") else { return }

        var req = URLRequest(url: url, timeoutInterval: 12)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let workflow = try? JSONDecoder().decode(LilithWorkflow.self, from: data)
            else { return }
            DispatchQueue.main.async {
                self.run(workflow)
            }
        }.resume()
    }

    // MARK: - Step Execution

    private func executeStep(_ steps: [LilithStep], index: Int) {
        guard index < steps.count else { return }

        let step = steps[index]
        perform(step) {
            self.executeStep(steps, index: index + 1)
        }
    }

    // MARK: - Perform Step

    private func perform(_ step: LilithStep, completion: @escaping () -> Void) {
        switch step.type {
        case "openURL":
            if let raw = step.payload["url"], let url = URL(string: raw) {
                open(url)
            }
            completion()

        case "openMaps":
            if let query = step.payload["query"] {
                let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
                    open(url)
                }
            }
            completion()

        case "notification":
            let text = step.payload["text"] ?? "Lilith update"
            NotificationCenter.default.post(name: .lilithWorkflowEvent, object: text)
            completion()

        case "delay":
            let seconds = Double(step.payload["seconds"] ?? "1") ?? 1
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                completion()
            }

        default:
            completion()
        }
    }

    private func open(_ url: URL) {
        DispatchQueue.main.async {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Notification Hook

extension Notification.Name {
    static let lilithWorkflowEvent = Notification.Name("lilithWorkflowEvent")
}

// MARK: - App Intents

@available(iOS 16.0, *)
struct OpenWebsiteIntent: AppIntent {

    static var title: LocalizedStringResource = "Open Website"

    @Parameter(title: "URL")
    var url: String

    func perform() async throws -> some IntentResult {
        if let link = URL(string: url) {
            await MainActor.run {
                UIApplication.shared.open(link)
            }
        }
        return .result()
    }
}

@available(iOS 16.0, *)
struct QuickReminderIntent: AppIntent {

    static var title: LocalizedStringResource = "Create Reminder"

    @Parameter(title: "Text")
    var text: String

    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .lilithWorkflowEvent, object: "Reminder: \(text)")
        return .result()
    }
}
