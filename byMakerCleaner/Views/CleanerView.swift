import SwiftUI

/// Main System Cleaner / Smart Scan screen.
/// Uses Text + .onTapGesture instead of Button to avoid Metal crash on Kepler GPU.
struct CleanerView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────
            headerView
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

            Rectangle()
                .fill(Theme.border)
                .frame(height: 1)

            // ── Content ─────────────────────────────────────────────
            switch appState.scanState {
            case .idle:
                idleView
            case .scanning(let path):
                scanningView(path: path)
            case .done:
                resultsView
            case .cleaning:
                cleaningView
            case .cleanDone(let freed, let hasTrashItems):
                cleanDoneView(freed: freed, hasTrashItems: hasTrashItems)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("🧹 Smart Scan")
                    .font(.title2).bold()
                Text("Find and remove junk from your Mac")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if appState.scanState == .done {
                TerminalButton("RESCAN", icon: "arrow.clockwise") {
                    appState.startSystemScan()
                }
            }
        }
        .foregroundColor(Theme.textPrimary)
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🔍")
                .font(.system(size: 64))
            Text("Ready to Scan")
                .font(.title3).bold()
            Text("Scan will check system junk, caches, Xcode artifacts, AI app logs, and more.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            TerminalButton("INITIATE SCAN", icon: "magnifyingglass") {
                appState.startSystemScan()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Scanning

    private func scanningView(path: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🔍")
                .font(.system(size: 48))
            Text("Scanning…")
                .font(.title3).bold()
            Text(path.isEmpty ? "Preparing…" : URL(fileURLWithPath: path).lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 340)
            TerminalButton("ABORT", isDestructive: true) {
                appState.cancelSystemScan()
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Results

    private var resultsView: some View {
        VStack(spacing: 0) {
            // Summary bar
            summaryBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

            Rectangle().fill(Theme.border).frame(height: 1)
            
            // Bar Chart
            let chartItems = appState.categoryResults.map { result in
                BarChartItem(label: result.category.rawValue, value: Double(result.totalSize), color: Theme.accent)
            }
            if !chartItems.isEmpty {
                TerminalBarChart(items: chartItems, height: 80)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
            }

            // Category list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(appState.categoryResults) { result in
                        if !result.items.isEmpty {
                            TerminalCard(title: result.category.rawValue) {
                                CategoryRowView(result: result)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 80)
            }

            // Clean button
            if appState.hasSelectedItems {
                Rectangle().fill(Theme.border).frame(height: 1)
                HStack {
                    Text("SELECTED: **\(appState.totalSelectedSizeFormatted)**")
                        .font(Theme.font(size: 14))
                        .foregroundColor(Theme.textPrimary)
                    Spacer()
                    TerminalButton("PURGE \(appState.totalSelectedSizeFormatted)", icon: "trash", isDestructive: true) {
                        appState.cleanSelectedItems()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.surface)
            }
        }
    }

    private var summaryBar: some View {
        let totalSize = appState.categoryResults.reduce(0) { $0 + $1.totalSize }
        let totalFormatted = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        let categoryCount = appState.categoryResults.filter { !$0.items.isEmpty }.count

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FOUND **\(totalFormatted)** OF JUNK")
                    .font(Theme.font(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("\(categoryCount) CATEGORIES WITH ITEMS")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
        }
    }

    // MARK: - Cleaning / Done

    private var cleaningView: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("🗑️")
                .font(.system(size: 48))
            Text("Cleaning…")
                .font(.title3).bold()
            Text("Moving items to Trash. You can restore them from the Trash if needed.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func cleanDoneView(freed: Int64, hasTrashItems: Bool) -> some View {
        let formattedFreed = ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)

        // Message depends on what was cleaned:
        // - Trash Bins items were permanently deleted (not "moved to Trash")
        // - Regular items were moved to Trash (recoverable)
        let mainMessage: String
        let subMessage: String
        if hasTrashItems {
            mainMessage = "**\(formattedFreed)** freed"
            subMessage = "Trash Bins items were permanently deleted. Other items moved to Trash."
        } else {
            mainMessage = "**\(formattedFreed)** moved to Trash"
            subMessage = "Items are in your Trash — you can empty it or restore them from there."
        }

        return VStack(spacing: 20) {
            Spacer()
            Text("✅")
                .font(.system(size: 64))
            Text("Done!")
                .font(.title2).bold()
            Text(LocalizedStringKey(mainMessage))
                .font(.title3)
            Text(subMessage)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            TerminalButton("ACKNOWLEDGE", icon: "checkmark") {
                appState.startSystemScan() // resets to scan view
            }
            Spacer()
        }
        .foregroundColor(Theme.textPrimary)
        .frame(maxWidth: .infinity)
    }
}
