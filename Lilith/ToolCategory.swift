import SwiftUI

// MARK: - Tool Access Mode

enum ToolAccessMode: String, CaseIterable, Identifiable {
    case selfGuided = "Self-Guided"
    case lilithAssisted = "Lilith-Assisted"

    var id: String { rawValue }
}

// MARK: - Tool Entry

struct ToolEntry: Identifiable, Equatable {
    let id = UUID()
    let destination: WorkspaceDestination
    var mode: ToolAccessMode
    var isPinned: Bool
    var lastUsedAt: Date?

    static func == (lhs: ToolEntry, rhs: ToolEntry) -> Bool {
        lhs.destination == rhs.destination
    }

    var title: String { destination.title }
    var subtitle: String { destination.subtitle }
    var icon: String { destination.icon }
}

// MARK: - Tool Category

struct ToolCategory: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let destinations: [WorkspaceDestination]

    static func == (lhs: ToolCategory, rhs: ToolCategory) -> Bool {
        lhs.id == rhs.id
    }

    static let all: [ToolCategory] = [
        ToolCategory(
            id: "communication",
            title: "Communication",
            icon: "bubble.left.and.bubble.right",
            destinations: [.messages, .calls, .social]
        ),
        ToolCategory(
            id: "ai",
            title: "AI & Generation",
            icon: "sparkles",
            destinations: [.assistant, .image, .video]
        ),
        ToolCategory(
            id: "browser",
            title: "Browser & Search",
            icon: "globe",
            destinations: [.web]
        ),
        ToolCategory(
            id: "commerce",
            title: "Storefront & Commerce",
            icon: "storefront",
            destinations: [.tools]
        ),
        ToolCategory(
            id: "identity",
            title: "Accounts & Identity",
            icon: "person.crop.circle",
            destinations: [.account, .inbox, .vault]
        ),
        ToolCategory(
            id: "files",
            title: "Files & Media",
            icon: "doc.text",
            destinations: [.documents, .media]
        ),
        ToolCategory(
            id: "finance",
            title: "Payments & Finance",
            icon: "dollarsign.circle",
            destinations: [.finance]
        ),
        ToolCategory(
            id: "automation",
            title: "Automation & Tasks",
            icon: "gearshape.2",
            destinations: [.projects, .history, .activity, .memory]
        ),
        ToolCategory(
            id: "developer",
            title: "Developer & Advanced",
            icon: "chevron.left.forwardslash.chevron.right",
            destinations: [.legal, .clone, .code]
        ),
    ]
}

// MARK: - Tool Layer View Model

@MainActor
final class ToolLayerViewModel: ObservableObject {
    @Published var entries: [ToolEntry] = []
    @Published var searchQuery: String = ""
    @Published var selectedCategoryID: String? = nil

    @AppStorage("lilith.pinnedTools") private var pinnedToolsData: Data = Data()
    @AppStorage("lilith.recentTools") private var recentToolsData: Data = Data()

    init() {
        loadEntries()
    }

    var pinnedEntries: [ToolEntry] {
        entries.filter { $0.isPinned }
    }

    var recentEntries: [ToolEntry] {
        entries
            .filter { $0.lastUsedAt != nil }
            .sorted { ($0.lastUsedAt ?? .distantPast) > ($1.lastUsedAt ?? .distantPast) }
            .prefix(6)
            .map { $0 }
    }

    var filteredEntries: [ToolEntry] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if query.isEmpty { return entries }
        return entries.filter {
            $0.title.lowercased().contains(query) ||
            $0.subtitle.lowercased().contains(query)
        }
    }

    var entriesByCategory: [(ToolCategory, [ToolEntry])] {
        let base = searchQuery.isEmpty ? entries : filteredEntries
        return ToolCategory.all.compactMap { category in
            let categoryEntries = base.filter { category.destinations.contains($0.destination) }
            guard !categoryEntries.isEmpty else { return nil }
            return (category, categoryEntries)
        }
    }

    func togglePin(for entry: ToolEntry) {
        guard let index = entries.firstIndex(where: { $0.destination == entry.destination }) else { return }
        entries[index].isPinned.toggle()
        saveEntries()
    }

    func setMode(_ mode: ToolAccessMode, for entry: ToolEntry) {
        guard let index = entries.firstIndex(where: { $0.destination == entry.destination }) else { return }
        entries[index].mode = mode
        saveEntries()
    }

    func recordUse(for entry: ToolEntry) {
        guard let index = entries.firstIndex(where: { $0.destination == entry.destination }) else { return }
        entries[index].lastUsedAt = Date()
        saveEntries()
    }

    // MARK: - Persistence

    private func loadEntries() {
        var loaded: [ToolEntry] = []
        var pinnedIDs: Set<String> = []
        var recentDates: [String: Date] = [:]

        if let decoded = try? JSONDecoder().decode([String].self, from: pinnedToolsData) {
            pinnedIDs = Set(decoded)
        }
        if let decoded = try? JSONDecoder().decode([String: Date].self, from: recentToolsData) {
            recentDates = decoded
        }

        for category in ToolCategory.all {
            for destination in category.destinations {
                loaded.append(ToolEntry(
                    destination: destination,
                    mode: .selfGuided,
                    isPinned: pinnedIDs.contains(destination.rawValue),
                    lastUsedAt: recentDates[destination.rawValue]
                ))
            }
        }
        entries = loaded
    }

    private func saveEntries() {
        let pinnedIDs = entries.filter { $0.isPinned }.map { $0.destination.rawValue }
        let recentDates = Dictionary(uniqueKeysWithValues: entries.compactMap { entry -> (String, Date)? in
            guard let date = entry.lastUsedAt else { return nil }
            return (entry.destination.rawValue, date)
        })
        pinnedToolsData = (try? JSONEncoder().encode(pinnedIDs)) ?? Data()
        recentToolsData = (try? JSONEncoder().encode(recentDates)) ?? Data()
    }
}
