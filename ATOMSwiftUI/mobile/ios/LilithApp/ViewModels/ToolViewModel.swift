import Foundation

@MainActor
final class ToolViewModel: ObservableObject {
    @Published var toolName: String = "text_summarizer"
    @Published var inputText: String = ""
    @Published var resultText: String = ""
    @Published var error: String?

    private let service = ToolService()

    func run() async {
        do {
            let run = try await service.runTool(name: toolName, input: ["text": inputText, "prompt": inputText, "hint": inputText])
            let result = try await service.fetchResult(jobID: run.job_id)
            resultText = String(describing: result.output_payload)
        } catch {
            error = String(describing: error)
        }
    }
}

