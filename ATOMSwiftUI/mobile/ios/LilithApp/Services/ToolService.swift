import Foundation

struct ToolRunPayload: Encodable {
    let tool_name: String
    let input_payload: [String: String]
}

final class ToolService {
    private let api = APIClient.shared

    func runTool(name: String, input: [String: String]) async throws -> ToolRunResponse {
        try await api.post("/api/v1/tools/run", body: ToolRunPayload(tool_name: name, input_payload: input))
    }

    func fetchJob(jobID: String) async throws -> ToolJob {
        try await api.get("/api/v1/tools/jobs/\(jobID)")
    }

    func fetchResult(jobID: String) async throws -> ToolResult {
        try await api.get("/api/v1/tools/results/\(jobID)")
    }
}

