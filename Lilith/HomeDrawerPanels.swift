import SwiftUI

// MARK: - Home Left Drawer
// AI Tools, Notifications, News, Contacts

struct HomeLeftDrawer: View {
    var onSelectTool: (WorkspaceDestination) -> Void
    var onSelectContact: (String) -> Void

    @State private var selectedSection: LeftSection = .aiTools

    enum LeftSection: String, CaseIterable {
        case aiTools = "AI Tools"
        case notifications = "Notifications"
        case news = "News"
        case contacts = "Contacts"

        var icon: String {
            switch self {
            case .aiTools: return "sparkles"
            case .notifications: return "bell"
            case .news: return "newspaper"
            case .contacts: return "person.2"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Lilith")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(white: 0.9))

                Spacer()

                Circle()
                    .fill(Color.green.opacity(0.4))
                    .frame(width: 8, height: 8)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Section tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(LeftSection.allCases, id: \.self) { section in
                        Button(action: { selectedSection = section }) {
                            HStack(spacing: 6) {
                                Image(systemName: section.icon)
                                    .font(.system(size: 11))
                                Text(section.rawValue)
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(selectedSection == section ? Color.black : Color(white: 0.6))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedSection == section ? Color(white: 0.85) : Color(white: 0.08))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 8)

            // Content
            ScrollView {
                VStack(spacing: 0) {
                    switch selectedSection {
                    case .aiTools:
                        aiToolsContent
                    case .notifications:
                        notificationsContent
                    case .news:
                        newsContent
                    case .contacts:
                        contactsContent
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }

            Spacer()
        }
    }

    // MARK: - AI Tools

    private var aiToolsContent: some View {
        VStack(spacing: 10) {
            aiToolCard(
                icon: "photo",
                title: "Image Generation",
                subtitle: "Create visuals from text",
                destination: .image
            )
            aiToolCard(
                icon: "text.alignleft",
                title: "Text Summarize",
                subtitle: "Compress long content",
                destination: .assistant
            )
            aiToolCard(
                icon: "video",
                title: "Video Analyzer",
                subtitle: "Extract insights from video",
                destination: .video
            )
            aiToolCard(
                icon: "globe",
                title: "Nexus Browser",
                subtitle: "Search and scrape the web",
                destination: .web
            )
            aiToolCard(
                icon: "doc.text",
                title: "Document AI",
                subtitle: "Read and analyze files",
                destination: .documents
            )
            aiToolCard(
                icon: "chevron.left.forwardslash.chevron.right",
                title: "Code Builder",
                subtitle: "Generate and review code",
                destination: .code
            )
        }
        .padding(.top, 8)
    }

    private func aiToolCard(icon: String, title: String, subtitle: String, destination: WorkspaceDestination) -> some View {
        Button(action: { onSelectTool(destination) }) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.08))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color(white: 0.6))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.9))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.4))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.25))
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(white: 0.12).opacity(0.4), lineWidth: 0.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Notifications

    private var notificationsContent: some View {
        VStack(spacing: 10) {
            notificationCard(
                icon: "bell.badge",
                color: .orange,
                title: "Meeting reminder",
                subtitle: "OpenAI sync in 15 minutes",
                time: "10m ago"
            )
            notificationCard(
                icon: "envelope",
                color: .blue,
                title: "New message",
                subtitle: "Chloe sent you a file",
                time: "32m ago"
            )
            notificationCard(
                icon: "checkmark.shield",
                color: .green,
                title: "Security alert",
                subtitle: "Vault backup completed",
                time: "1h ago"
            )
        }
        .padding(.top, 8)
    }

    private func notificationCard(icon: String, color: Color, title: String, subtitle: String, time: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(color.opacity(0.8))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.9))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(white: 0.4))
            }

            Spacer()

            Text(time)
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.3))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.04))
        )
    }

    // MARK: - News

    private var newsContent: some View {
        VStack(spacing: 12) {
            newsCard(
                source: "techpulse.ai",
                headline: "Major Tech Event Tomorrow",
                snippet: "OpenAI announces new multimodal capabilities..."
            )
            newsCard(
                source: "futureai.com",
                headline: "AI Regulation Update",
                snippet: "EU passes new framework for artificial intelligence..."
            )
            newsCard(
                source: "neural.news",
                headline: "Breakthrough in Robotics",
                snippet: "Humanoid robots achieve new dexterity milestone..."
            )
        }
        .padding(.top, 8)
    }

    private func newsCard(source: String, headline: String, snippet: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(source)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(white: 0.35))

            Text(headline)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(white: 0.85))
                .lineLimit(2)

            Text(snippet)
                .font(.system(size: 11))
                .foregroundStyle(Color(white: 0.4))
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(white: 0.1).opacity(0.3), lineWidth: 0.5)
                )
        )
    }

    // MARK: - Contacts

    private var contactsContent: some View {
        VStack(spacing: 8) {
            contactRow(name: "Chloe", handle: "@chloe", status: "Active")
            contactRow(name: "Antonio", handle: "@antonio", status: "Away")
            contactRow(name: "Hanna", handle: "@hanna", status: "Active")
            contactRow(name: "Max", handle: "@max", status: "Offline")
            contactRow(name: "Sarah", handle: "@sarah", status: "Active")
        }
        .padding(.top, 8)
    }

    private func contactRow(name: String, handle: String, status: String) -> some View {
        Button(action: { onSelectContact(handle) }) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color(white: 0.12))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(name.prefix(1)))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(white: 0.7))
                        )

                    Circle()
                        .fill(statusColor(status))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color(white: 0.04), lineWidth: 2))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(white: 0.9))
                    Text(handle)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.4))
                }

                Spacer()

                Text(status)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(statusColor(status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(statusColor(status).opacity(0.12))
                    )
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func statusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "active": return .green
        case "away": return .orange
        default: return Color(white: 0.3)
        }
    }
}

// MARK: - Home Right Drawer
// Stats, App Shortcuts, Quick Tools

struct HomeRightDrawer: View {
    var onSelectTool: (WorkspaceDestination) -> Void
    var onOpenVault: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                Text("Dashboard")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(white: 0.9))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 16) {
                    // Stats card
                    statsCard

                    // App shortcuts
                    appShortcutsGrid

                    // Quick tools
                    quickToolsGrid

                    // Finance snapshot
                    financeSnapshot
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }

            Spacer()
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("24,336")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(white: 0.9))
                    Text("credits earned")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(white: 0.4))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 10, weight: .bold))
                    Text("+12%")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Color.green.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.green.opacity(0.1))
                )
            }

            Divider()
                .background(Color(white: 0.12))

            HStack(spacing: 16) {
                statItem(value: "3,240", label: "Tasks")
                statItem(value: "12.7k", label: "Messages")
                statItem(value: "$4,230", label: "Volume")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(white: 0.12).opacity(0.4), lineWidth: 0.5)
                )
        )
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color(white: 0.85))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(Color(white: 0.4))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - App Shortcuts

    private var appShortcutsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App Shortcuts")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.5))

            HStack(spacing: 10) {
                appShortcut(icon: "globe", label: "Browser", color: .blue)
                appShortcut(icon: "message", label: "Boop", color: .green)
                appShortcut(icon: "sparkles", label: "AI Tools", color: .purple)
                appShortcut(icon: "lock.shield", label: "Vault", color: .orange, action: onOpenVault)
            }
        }
    }

    private func appShortcut(icon: String, label: String, color: Color, action: (() -> Void)? = nil) -> some View {
        Button(action: { action?() }) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(white: 0.08))
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(color.opacity(0.8))
                    )

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.5))
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Tools

    private var quickToolsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Tools")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.5))

            VStack(spacing: 6) {
                quickToolRow(icon: "mic", label: "Voice Transcription", destination: .assistant)
                quickToolRow(icon: "text.alignleft", label: "Text Summarization", destination: .assistant)
                quickToolRow(icon: "photo", label: "Screenshot Analysis", destination: .image)
                quickToolRow(icon: "doc.text", label: "Contract Review", destination: .legal)
            }
        }
    }

    private func quickToolRow(icon: String, label: String, destination: WorkspaceDestination) -> some View {
        Button(action: { onSelectTool(destination) }) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.5))
                    .frame(width: 28, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(white: 0.08))
                    )

                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(white: 0.75))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(white: 0.25))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(white: 0.04))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Finance Snapshot

    private var financeSnapshot: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Finance")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.5))

                Spacer()

                Button(action: { onSelectTool(.finance) }) {
                    Text("Open")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(white: 0.5))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                financeMiniCard(icon: "arrow.up.arrow.down", label: "Send", color: .blue)
                financeMiniCard(icon: "arrow.down.circle", label: "Request", color: .green)
                financeMiniCard(icon: "creditcard", label: "Cards", color: .orange)
            }
        }
    }

    private func financeMiniCard(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color.opacity(0.8))

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Color(white: 0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(white: 0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(white: 0.1).opacity(0.3), lineWidth: 0.5)
                )
        )
    }
}
