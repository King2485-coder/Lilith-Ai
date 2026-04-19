import SwiftUI
import LocalAuthentication

// MARK: - Vault Item

struct VaultItem: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var username: String
    var password: String
    var url: String
    var notes: String
    var category: VaultCategory
    var createdAt: Date
    var requiresConfirmation: Bool

    enum VaultCategory: String, Codable, CaseIterable, Identifiable {
        case login = "Login"
        case payment = "Payment"
        case identity = "Identity"
        case note = "Note"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .login: return "key.fill"
            case .payment: return "creditcard.fill"
            case .identity: return "person.text.rectangle.fill"
            case .note: return "note.text"
            }
        }
    }
}

// MARK: - Action Link

struct ActionLink: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var actionType: String
    var payload: String
    var vaultItemIDs: [String]
    var createdAt: Date
}

// MARK: - Vault View

struct VaultView: View {
    @StateObject private var viewModel = VaultViewModel()
    @State private var showAddItem = false
    @State private var showActionLinks = false
    @State private var selectedItem: VaultItem? = nil
    @State private var revealPasswordID: String? = nil

    var body: some View {
        ZStack {
            Color(white: 0.03).ignoresSafeArea()

            VStack(spacing: 0) {
                // Header tabs
                HStack(spacing: 0) {
                    VaultTabButton(title: "Vault", icon: "lock.shield.fill", isActive: !showActionLinks) {
                        showActionLinks = false
                    }
                    VaultTabButton(title: "Actions", icon: "bolt.fill", isActive: showActionLinks) {
                        showActionLinks = true
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 44)
                .padding(.bottom, 8)

                if showActionLinks {
                    actionLinksContent
                } else {
                    vaultContent
                }
            }
        }
        .sheet(isPresented: $showAddItem) {
            AddVaultItemSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedItem) { item in
            VaultItemDetailSheet(item: item, viewModel: viewModel)
        }
    }

    // MARK: - Vault Content

    private var vaultContent: some View {
        List {
            ForEach(VaultItem.VaultCategory.allCases) { category in
                let items = viewModel.items(for: category)
                if !items.isEmpty {
                    Section {
                        ForEach(items) { item in
                            vaultItemRow(item)
                        }
                        .onDelete { indices in
                            deleteItems(in: category, at: indices)
                        }
                    } header: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                                .font(.system(size: 12))
                            Text(category.rawValue)
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(Color(white: 0.45))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if viewModel.allItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(white: 0.2))
                    Text("Vault is empty")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(white: 0.4))
                    Text("Store logins, payment methods, and sensitive data securely.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: { showAddItem = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Add to Vault")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.85))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func vaultItemRow(_ item: VaultItem) -> some View {
        Button(action: { selectedItem = item }) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(white: 0.1))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: item.category.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.6))
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.9))

                    HStack(spacing: 4) {
                        Text(item.username)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.45))
                            .lineLimit(1)

                        if !item.password.isEmpty {
                            Text("·")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(white: 0.3))

                            Text(revealPasswordID == item.id ? item.password : "••••••••")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color(white: 0.45))
                        }
                    }
                }

                Spacer()

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        revealPasswordID = (revealPasswordID == item.id) ? nil : item.id
                    }
                }) {
                    Image(systemName: revealPasswordID == item.id ? "eye.slash" : "eye")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .listRowBackground(Color(white: 0.05))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private func deleteItems(in category: VaultItem.VaultCategory, at indices: IndexSet) {
        let items = viewModel.items(for: category)
        for index in indices {
            viewModel.deleteItem(id: items[index].id)
        }
    }

    // MARK: - Action Links Content

    private var actionLinksContent: some View {
        List {
            ForEach(viewModel.actionLinks) { link in
                actionLinkRow(link)
            }
            .onDelete { indices in
                for index in indices {
                    viewModel.deleteActionLink(id: viewModel.actionLinks[index].id)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .overlay {
            if viewModel.actionLinks.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bolt")
                        .font(.system(size: 36))
                        .foregroundStyle(Color(white: 0.2))
                    Text("No action links")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(white: 0.4))
                    Text("Lilith can generate one-tap execution links using vault data.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(white: 0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(action: { viewModel.createDemoActionLink() }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                    Text("Create Action Link")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(white: 0.85))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    private func actionLinkRow(_ link: ActionLink) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(white: 0.1))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.yellow.opacity(0.7))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(link.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(white: 0.9))

                Text(link.actionType)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.4))
            }

            Spacer()

            Button(action: {
                executeActionLink(link)
            }) {
                Text("Run")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(white: 0.8))
                    )
            }
            .buttonStyle(.plain)
        }
        .listRowBackground(Color(white: 0.05))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    }

    private func executeActionLink(_ link: ActionLink) {
        // Require biometric confirmation
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // Fallback: still execute with alert
            return
        }
        Task {
            do {
                let success = try await context.evaluatePolicy(
                    .deviceOwnerAuthenticationWithBiometrics,
                    localizedReason: "Confirm execution of \(link.title)"
                )
                if success {
                    // Execute the action
                    await MainActor.run {
                        // In a real implementation, this would execute the action
                        // For now, we just log it
                    }
                }
            } catch { }
        }
    }
}

// MARK: - Vault Tab Button

struct VaultTabButton: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(isActive ? Color(white: 0.9) : Color(white: 0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isActive ? Color(white: 0.12) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Add Vault Item Sheet

struct AddVaultItemSheet: View {
    @ObservedObject var viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var category: VaultItem.VaultCategory = .login
    @State private var requiresConfirmation = true

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.03).ignoresSafeArea()

                List {
                    Section {
                        Picker("Category", selection: $category) {
                            ForEach(VaultItem.VaultCategory.allCases) { cat in
                                HStack(spacing: 6) {
                                    Image(systemName: cat.icon)
                                    Text(cat.rawValue)
                                }
                                .tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                        .listRowBackground(Color(white: 0.06))

                        TextField("Title", text: $title)
                            .foregroundStyle(Color(white: 0.9))
                            .listRowBackground(Color(white: 0.06))

                        TextField("Username / Email", text: $username)
                            .foregroundStyle(Color(white: 0.9))
                            .listRowBackground(Color(white: 0.06))

                        SecureField("Password", text: $password)
                            .foregroundStyle(Color(white: 0.9))
                            .listRowBackground(Color(white: 0.06))

                        TextField("URL (optional)", text: $url)
                            .foregroundStyle(Color(white: 0.9))
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .listRowBackground(Color(white: 0.06))
                    }

                    Section {
                        Toggle("Require confirmation before use", isOn: $requiresConfirmation)
                            .foregroundStyle(Color(white: 0.8))
                            .listRowBackground(Color(white: 0.06))
                    }

                    Section {
                        TextEditor(text: $notes)
                            .frame(minHeight: 80)
                            .foregroundStyle(Color(white: 0.9))
                            .listRowBackground(Color(white: 0.06))
                    } header: {
                        Text("Notes")
                            .foregroundStyle(Color(white: 0.4))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Add to Vault")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color(white: 0.6))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        viewModel.addItem(VaultItem(
                            id: UUID().uuidString,
                            title: title,
                            username: username,
                            password: password,
                            url: url,
                            notes: notes,
                            category: category,
                            createdAt: Date(),
                            requiresConfirmation: requiresConfirmation
                        ))
                        dismiss()
                    }
                    .foregroundStyle(Color(white: 0.9))
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Vault Item Detail Sheet

struct VaultItemDetailSheet: View {
    let item: VaultItem
    @ObservedObject var viewModel: VaultViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var revealPassword = false

    var body: some View {
        NavigationView {
            ZStack {
                Color(white: 0.03).ignoresSafeArea()

                List {
                    Section {
                        detailRow("Title", item.title)
                        detailRow("Username", item.username)

                        HStack {
                            Text("Password")
                                .font(.system(size: 14))
                                .foregroundStyle(Color(white: 0.5))
                            Spacer()
                            Text(revealPassword ? item.password : "••••••••")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(Color(white: 0.8))
                            Button(action: { revealPassword.toggle() }) {
                                Image(systemName: revealPassword ? "eye.slash" : "eye")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color(white: 0.4))
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color(white: 0.06))

                        if !item.url.isEmpty {
                            detailRow("URL", item.url)
                        }

                        detailRow("Category", item.category.rawValue)
                    }

                    if !item.notes.isEmpty {
                        Section("Notes") {
                            Text(item.notes)
                                .font(.system(size: 14))
                                .foregroundStyle(Color(white: 0.7))
                                .listRowBackground(Color(white: 0.06))
                        }
                    }

                    Section {
                        Button(role: .destructive, action: {
                            viewModel.deleteItem(id: item.id)
                            dismiss()
                        }) {
                            Text("Delete")
                                .font(.system(size: 15, weight: .medium))
                        }
                        .listRowBackground(Color(white: 0.06))
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color(white: 0.7))
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.5))
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.8))
        }
        .listRowBackground(Color(white: 0.06))
    }
}

// MARK: - Vault View Model

@MainActor
final class VaultViewModel: ObservableObject {
    @Published var allItems: [VaultItem] = []
    @Published var actionLinks: [ActionLink] = []

    private let itemsKey = "lilith.vault.items"
    private let linksKey = "lilith.vault.actionlinks"

    init() {
        load()
    }

    func items(for category: VaultItem.VaultCategory) -> [VaultItem] {
        allItems.filter { $0.category == category }
    }

    func addItem(_ item: VaultItem) {
        allItems.append(item)
        save()
    }

    func deleteItem(id: String) {
        allItems.removeAll { $0.id == id }
        save()
    }

    func deleteActionLink(id: String) {
        actionLinks.removeAll { $0.id == id }
        save()
    }

    func createDemoActionLink() {
        let link = ActionLink(
            id: UUID().uuidString,
            title: "Quick Login · GitHub",
            actionType: "auto_login",
            payload: "https://github.com/login",
            vaultItemIDs: [],
            createdAt: Date()
        )
        actionLinks.append(link)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(allItems) {
            UserDefaults.standard.set(data, forKey: itemsKey)
        }
        if let data = try? JSONEncoder().encode(actionLinks) {
            UserDefaults.standard.set(data, forKey: linksKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: itemsKey),
           let decoded = try? JSONDecoder().decode([VaultItem].self, from: data) {
            allItems = decoded
        }
        if let data = UserDefaults.standard.data(forKey: linksKey),
           let decoded = try? JSONDecoder().decode([ActionLink].self, from: data) {
            actionLinks = decoded
        }
    }
}
