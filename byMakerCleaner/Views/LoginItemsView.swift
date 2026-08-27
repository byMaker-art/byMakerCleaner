import SwiftUI

/// Login Items manager — shows app login items, user LaunchAgents, and system services.
/// UI style matches OrphanFinderView: header bar + list + action footer.
/// GPU-safe: Text + .onTapGesture only.
struct LoginItemsView: View {
    @StateObject private var manager = LoginItemsManager()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
        }
        .onAppear { manager.scanAll() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("⚙️ Login Items")
                    .font(.headline)
                Text("Apps and services that launch at startup")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if manager.isScanning {
                Text("Scanning...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            refreshButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var refreshButton: some View {
        let isScanning = manager.isScanning
        return Text(isScanning ? "..." : "Refresh")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isScanning ? .secondary : .accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(isScanning ? 0.05 : 0.12))
            .cornerRadius(6)
            .onTapGesture { if !isScanning { manager.scanAll() } }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if manager.items.isEmpty && !manager.isScanning {
            VStack(spacing: 12) {
                Text("✅").font(.system(size: 40))
                Text("No login items found.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            itemList
        }
    }

    // MARK: - Item list

    private var itemList: some View {
        List {
            // ── Apps (Open at Login) ───────────────────────────────────
            let apps = manager.items.filter { $0.type == .app }
            if !apps.isEmpty {
                sectionHeader(title: "🚀 Apps (Open at Login)", count: apps.count)
                ForEach(apps) { item in
                    itemRow(for: item)
                        .listRowSeparator(.visible)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            // ── User LaunchAgents ──────────────────────────────────────
            let userAgents = manager.items.filter { $0.type == .userAgent }
            if !userAgents.isEmpty {
                sectionHeader(title: "🔧 User Background Services", count: userAgents.count)
                ForEach(userAgents) { item in
                    itemRow(for: item)
                        .listRowSeparator(.visible)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }

            // ── System Daemons / Agents ────────────────────────────────
            let systemItems = manager.items.filter { $0.type == .systemAgent || $0.type == .systemDaemon }
            if !systemItems.isEmpty {
                sectionHeaderWithAction(
                    title: "🔒 System Background Services",
                    count: systemItems.count,
                    action: { manager.openSystemSettingsLoginItems() },
                    actionLabel: "Open System Settings"
                )
                ForEach(systemItems) { item in
                    itemRow(for: item)
                        .listRowSeparator(.visible)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Section headers

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("(\(count))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }

    private func sectionHeaderWithAction(
        title: String,
        count: Int,
        action: @escaping () -> Void,
        actionLabel: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("(\(count))")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(actionLabel)
                .font(.caption)
                .foregroundColor(.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.1))
                .onTapGesture { action() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(NSColor.windowBackgroundColor))
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
    }

    // MARK: - Row

    @ViewBuilder
    private func itemRow(for item: LoginItemModel) -> some View {
        HStack(spacing: 8) {

            // ── LEFT: status control (like OrphanFinder's checkbox) ──────────
            switch item.type {
            case .app:
                // ☐/☑ Hide toggle — acts as the "checkbox" for this item
                Text(item.isHidden ? "☑" : "☐")
                    .font(.system(size: 16))
                    .foregroundColor(item.isHidden ? .accentColor : .secondary)
                    .onTapGesture { manager.toggleHiddenForApp(item) }

            case .userAgent:
                // ☐/☑ Enabled toggle
                Text(item.isEnabled ? "☑" : "☐")
                    .font(.system(size: 16))
                    .foregroundColor(item.isEnabled ? .accentColor : .secondary)
                    .onTapGesture { manager.toggleAgentEnabled(item) }

            default:
                // 🔒 read-only system item
                Text("🔒")
                    .font(.system(size: 14))
            }

            // ── MIDDLE: name + path ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(1)
                Text(item.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .onTapGesture {
                // Tap on the name row also toggles the control (for apps/agents)
                switch item.type {
                case .app:       manager.toggleHiddenForApp(item)
                case .userAgent: manager.toggleAgentEnabled(item)
                default:         break
                }
            }

            Spacer()

            // ── RIGHT: Remove (apps only) + Finder ───────────────────────────
            if item.type == .app {
                Text("Remove")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(4)
                    .onTapGesture { manager.removeApp(item) }
            }

            Text("Finder")
                .font(.caption)
                .foregroundColor(.accentColor)
                .onTapGesture { manager.revealInFinder(path: item.path) }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers (unused icon helper removed — type displayed inline above)
}

