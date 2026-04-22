import Foundation

// MARK: - Memory Vector Entry

struct MemoryEntry: Codable, Identifiable {
    let id       : UUID
    let text     : String
    let embedding: [Double]
    let date     : Date
}

// MARK: - Vector Memory Store

final class LilithVectorMemory {

    static let shared = LilithVectorMemory()

    private let key = "lilith_vector_memory"
    private(set) var memories: [MemoryEntry] = []

    private init() { load() }

    func save() {
        if let data = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([MemoryEntry].self, from: data) {
            memories = decoded
        }
    }

    func add(text: String, embedding: [Double]) {
        let entry = MemoryEntry(id: UUID(), text: text, embedding: embedding, date: Date())
        memories.append(entry)
        if memories.count > 200 { memories.removeFirst() }
        save()
    }

    // Cosine similarity
    private func similarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        let dot  = zip(a, b).map(*).reduce(0, +)
        let magA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magB = sqrt(b.map { $0 * $0 }.reduce(0, +))
        return dot / (magA * magB + 1e-9)
    }

    func retrieveRelevant(queryEmbedding: [Double], topK: Int = 5) -> [MemoryEntry] {
        memories
            .map { ($0, similarity(queryEmbedding, $0.embedding)) }
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map(\.0)
    }
}

// MARK: - Network Codables

struct EmbeddingResponse: Decodable { let embedding: [Double] }
struct ChatMemoryResponse: Decodable { let reply: String }

// MARK: - GPT Service (chat + embeddings)

final class LilithGPTService {

    static let shared = LilithGPTService()
    private let base = "http://127.0.0.1:8000"

    private init() {}

    /// Fetches an embedding vector for `text` from the backend.
    func embedding(for text: String, completion: @escaping ([Double]) -> Void) {
        guard let url = URL(string: "\(base)/api/embed") else { return }
        var req = URLRequest(url: url, timeoutInterval: 8)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["text": text])

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let res = try? JSONDecoder().decode(EmbeddingResponse.self, from: data)
            else { return }
            DispatchQueue.main.async { completion(res.embedding) }
        }.resume()
    }

    /// Sends a chat message with optional memory context strings.
    func chat(message: String,
              memory: [String],
              systemPrompt: String,
              completion: @escaping (String) -> Void) {
        guard let url = URL(string: "\(base)/api/chat") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "message": message,
            "memory": memory,
            "system_prompt": systemPrompt
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let res = try? JSONDecoder().decode(ChatMemoryResponse.self, from: data)
            else { return }
            DispatchQueue.main.async { completion(res.reply) }
        }.resume()
    }
}

// MARK: - Brain V2 (embedding → recall → chat → store)

final class LilithBrainV2 {

    static let shared = LilithBrainV2()
    private init() {}

    func process(userText: String, completion: @escaping (String) -> Void) {

        // Update adaptive personality/relationship state before generating response.
        LilithPersonalityEngine.shared.learn(from: userText)
        LilithRelationshipEngine.shared.update(userText: userText)
        let adaptiveSystemPrompt =
            LilithPersonalityEngine.shared.systemPrompt()
            + "\n\n"
            + LilithRelationshipEngine.shared.systemPrompt()

        // 1. Embed the user input
        LilithGPTService.shared.embedding(for: userText) { embedding in

            // 2. Retrieve semantically relevant memory
            let context = LilithVectorMemory.shared
                .retrieveRelevant(queryEmbedding: embedding)
                .map(\.text)

            // 3. Chat with memory context
            LilithGPTService.shared.chat(
                message: userText,
                memory: context,
                systemPrompt: adaptiveSystemPrompt
            ) { reply in

                // 4. Store user message
                LilithVectorMemory.shared.add(text: userText, embedding: embedding)

                // 5. Store reply (async embed, fire-and-forget)
                LilithGPTService.shared.embedding(for: reply) { replyEmbed in
                    LilithVectorMemory.shared.add(text: reply, embedding: replyEmbed)
                }

                completion(reply)
            }
        }
    }
}
