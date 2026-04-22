import Foundation

class NetworkService {
    static let shared = NetworkService()
    
    private init() {}
    
    func loginUser(email: String, password: String) async throws -> AppUser {
        let url = URL(string: "\(AppConstants.baseUrl)/data/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "app_id": AppConstants.appId,
            "email": email,
            "password": password,
            "provider": "email"
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("→ Request: Login User")
        print("→ (POST): \(url.absoluteString)")
        print("→ Parameters:")
        print(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("← Response: Login User")
        print("← (POST): \(url.absoluteString)")
        print("← Status Code: \(httpResponse.statusCode)")
        print("← Response Body:")
        print(String(data: data, encoding: .utf8) ?? "")
        
        if httpResponse.statusCode == 400 {
            throw NSError(domain: "", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid credentials"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let user = try JSONDecoder().decode(AppUser.self, from: data)
        return user
    }
    
    func createUser(email: String, password: String) async throws -> AppUser {
        let url = URL(string: "\(AppConstants.baseUrl)/data")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "app_id": AppConstants.appId,
            "table_name": "users",
            "data": [
                "email": email,
                "password": password,
                "provider": "email"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        print("→ Request: Create User")
        print("→ (POST): \(url.absoluteString)")
        print("→ Parameters:")
        print(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("← Response: Create User")
        print("← (POST): \(url.absoluteString)")
        print("← Status Code: \(httpResponse.statusCode)")
        print("← Response Body:")
        print(String(data: data, encoding: .utf8) ?? "")
        
        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        
        let user = try JSONDecoder().decode(AppUser.self, from: data)
        return user
    }
    
    func deleteUser(userId: String) async throws {
        var components = URLComponents(string: "\(AppConstants.baseUrl)/data")!
        components.queryItems = [
            URLQueryItem(name: "app_id", value: AppConstants.appId),
            URLQueryItem(name: "table_name", value: "users"),
            URLQueryItem(name: "id", value: userId)
        ]
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("→ Request: Delete User")
        print("→ (DELETE): \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        print("← Response: Delete User")
        print("← (DELETE): \(url.absoluteString)")
        print("← Status Code: \(httpResponse.statusCode)")
        print("← Response Body:")
        print(String(data: data, encoding: .utf8) ?? "")
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
}