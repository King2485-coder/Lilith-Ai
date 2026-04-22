import Foundation

struct AppUser: Identifiable, Hashable, Codable {
    var id: String?
    var email: String?
    var provider: String?
    var createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case provider
        case createdAt = "created_at"
    }
}

struct LinuxMachine: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var hostname: String
    var ipAddress: String
    var port: Int
    var username: String
    var authMethod: String
    var isConnected: Bool
    
    init(id: UUID = UUID(), name: String, hostname: String, ipAddress: String, port: Int = 22, username: String, authMethod: String = "password", isConnected: Bool = false) {
        self.id = id
        self.name = name
        self.hostname = hostname
        self.ipAddress = ipAddress
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.isConnected = isConnected
    }
}

struct TerminalCommand: Identifiable, Hashable {
    let id: UUID
    let command: String
    let output: String
    let timestamp: Date
    
    init(id: UUID = UUID(), command: String, output: String, timestamp: Date = Date()) {
        self.id = id
        self.command = command
        self.output = output
        self.timestamp = timestamp
    }
}

struct SystemInfo: Identifiable, Hashable {
    let id: UUID
    var cpuUsage: Double
    var memoryTotal: String
    var memoryUsed: String
    var memoryPercentage: Double
    var diskUsage: String
    var diskPercentage: Double
    var networkInfo: String
    
    init(id: UUID = UUID(), cpuUsage: Double = 0, memoryTotal: String = "0 GB", memoryUsed: String = "0 GB", memoryPercentage: Double = 0, diskUsage: String = "0 GB", diskPercentage: Double = 0, networkInfo: String = "N/A") {
        self.id = id
        self.cpuUsage = cpuUsage
        self.memoryTotal = memoryTotal
        self.memoryUsed = memoryUsed
        self.memoryPercentage = memoryPercentage
        self.diskUsage = diskUsage
        self.diskPercentage = diskPercentage
        self.networkInfo = networkInfo
    }
}

struct ProcessInfo: Identifiable, Hashable {
    let id: UUID
    let pid: String
    let name: String
    let cpuUsage: Double
    let memoryUsage: String
    
    init(id: UUID = UUID(), pid: String, name: String, cpuUsage: Double, memoryUsage: String) {
        self.id = id
        self.pid = pid
        self.name = name
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
    }
}

struct FileItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let isDirectory: Bool
    let size: String
    let modifiedDate: String
    let permissions: String
    
    init(id: UUID = UUID(), name: String, isDirectory: Bool, size: String = "", modifiedDate: String = "", permissions: String = "") {
        self.id = id
        self.name = name
        self.isDirectory = isDirectory
        self.size = size
        self.modifiedDate = modifiedDate
        self.permissions = permissions
    }
}