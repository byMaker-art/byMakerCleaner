import SwiftUI

/// Login Items manager — shows app login items, user LaunchAgents, and system services.
/// UI style matches OrphanFinderView: header bar + list + action footer.
/// GPU-safe: Text + .onTapGesture only.
struct LoginItemsView: View {
    @StateObject private var manager = LoginItemsManager()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(Theme.border).frame(height: 1)
            contentArea
        }
        .background(Theme.background)
        .onAppear { manager.scanAll() }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("[ LOGIN ITEMS ]")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text("APPS AND SERVICES THAT LAUNCH AT STARTUP")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            if manager.isScanning {
                Text("SCANNING...")
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
            }
            refreshButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var refreshButton: some View {
        let isScanning = manager.isScanning
        
        return TerminalButton(isScanning ? "..." : "REFRESH", icon: "arrow.clockwise") {
            if !isScanning { manager.scanAll() }
        }
        .opacity(isScanning ? 0.5 : 1.0)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if manager.items.isEmpty && !manager.isScanning {
            VStack(spacing: 12) {
                Text("[ NO ITEMS FOUND ]")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundColor(Theme.success)
                Text("SYSTEM STARTUP IS CLEAN")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            itemList
        }
    }

    // MARK: - Item list

    private var itemList: some View {
        VStack(spacing: 0) {
            // ── Toolbar ─────────────────────────────────────────────────
            HStack(spacing: 0) {
                Spacer()

                Text("SORT:")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)
                    .padding(.trailing, 4)

                ForEach(LoginItemsManager.SortOrder.allCases, id: \.self) { order in
                    let isActive = manager.sortOrder == order
                    Text(order.rawValue.uppercased())
                        .font(Theme.font(size: 12, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? Theme.background : Theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isActive ? Theme.accent : Color.clear)
                        .border(isActive ? Theme.accent : Color.clear, width: 1)
                        .onTapGesture { manager.sortOrder = order }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.surface)

            Rectangle().fill(Theme.border).frame(height: 1)

            List {
                // ── Apps (Open at Login) ───────────────────────────────────
                let apps = manager.sortedItems(for: [.app])
                if !apps.isEmpty {
                    sectionHeader(title: "[+] APPS (OPEN AT LOGIN)", count: apps.count)
                    ForEach(apps) { item in
                        itemRow(for: item)
                            .listRowBackground(Theme.background)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }

                // ── User LaunchAgents ──────────────────────────────────────
                let userAgents = manager.sortedItems(for: [.userAgent])
                if !userAgents.isEmpty {
                    sectionHeader(title: "[+] USER BACKGROUND SERVICES", count: userAgents.count)
                    ForEach(userAgents) { item in
                        itemRow(for: item)
                            .listRowBackground(Theme.background)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }

                // ── System Daemons / Agents ────────────────────────────────
                let systemItems = manager.sortedItems(for: [.systemAgent, .systemDaemon])
                if !systemItems.isEmpty {
                    sectionHeaderWithAction(
                        title: "[🔒] SYSTEM BACKGROUND SERVICES",
                        count: systemItems.count,
                        action: { manager.openSystemSettingsLoginItems() },
                        actionLabel: "[ SETTINGS ]"
                    )
                    ForEach(systemItems) { item in
                        itemRow(for: item)
                            .listRowBackground(Theme.background)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
        }
    }

    // MARK: - Section headers

    private func sectionHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(Theme.font(size: 12, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("(\(count))")
                .font(Theme.font(size: 10))
                .foregroundColor(Theme.textMuted)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.background)
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
                .font(Theme.font(size: 12, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Text("(\(count))")
                .font(Theme.font(size: 10))
                .foregroundColor(Theme.textMuted)
            Spacer()
            Text(actionLabel)
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(Theme.accent)
                .onTapGesture { action() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.background)
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
                Text(item.isHidden ? "[X]" : "[ ]")
                    .font(Theme.font(size: 14))
                    .foregroundColor(item.isHidden ? Theme.accent : Theme.textMuted)
                    .frame(width: 24)
                    .onTapGesture { manager.toggleHiddenForApp(item) }

            case .userAgent:
                Text(item.isEnabled ? "[X]" : "[ ]")
                    .font(Theme.font(size: 14))
                    .foregroundColor(item.isEnabled ? Theme.accent : Theme.textMuted)
                    .frame(width: 24)
                    .onTapGesture { manager.toggleAgentEnabled(item) }

            default:
                Text("[🔒]")
                    .font(Theme.font(size: 14))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 24)
            }

            // ── MIDDLE: name + path ──────────────────────────────────────────
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name.uppercased())
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(item.path)
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
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
                Text("[ REMOVE ]")
                    .font(Theme.font(size: 10, weight: .bold))
                    .foregroundColor(Theme.destructive)
                    .onTapGesture { manager.removeApp(item) }
            }

            Text("[ FINDER ]")
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(Theme.accent)
                .onTapGesture { manager.revealInFinder(path: item.path) }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(Theme.surface)
        .border(Theme.border, width: 1)
    }

    // MARK: - Helpers (unused icon helper removed — type displayed inline above)
}

