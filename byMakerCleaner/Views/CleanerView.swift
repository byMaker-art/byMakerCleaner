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
                .padding(.top, 16)
                .padding(.bottom, 12)

            Divider()

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
            case .cleanDone(let freed):
                cleanDoneView(freed: freed)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
                Text("Scan Again")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(8)
                    .onTapGesture { appState.startSystemScan() }
            }
        }
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

            Text("Start Smart Scan")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .cornerRadius(10)
                .onTapGesture { appState.startSystemScan() }

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
            Text("Cancel")
                .font(.subheadline)
                .foregroundColor(.red)
                .onTapGesture { appState.cancelSystemScan() }
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

            Divider()

            // Category list
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(appState.categoryResults) { result in
                        if !result.items.isEmpty {
                            CategoryRowView(result: result)
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .padding(.bottom, 80)
            }

            // Clean button
            if appState.hasSelectedItems {
                Divider()
                HStack {
                    Text("Selected: **\(appState.totalSelectedSizeFormatted)**")
                        .font(.subheadline)
                    Spacer()
                    Text("🗑️  Clean \(appState.totalSelectedSizeFormatted)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.85))
                        .cornerRadius(8)
                        .onTapGesture { appState.cleanSelectedItems() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }
    }

    private var summaryBar: some View {
        let totalSize = appState.categoryResults.reduce(0) { $0 + $1.totalSize }
        let totalFormatted = ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        let categoryCount = appState.categoryResults.filter { !$0.items.isEmpty }.count

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Found **\(totalFormatted)** of junk")
                    .font(.subheadline)
                Text("\(categoryCount) categories with items")
                    .font(.caption)
                    .foregroundColor(.secondary)
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

    private func cleanDoneView(freed: Int64) -> some View {
        let formattedFreed = ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)
        return VStack(spacing: 20) {
            Spacer()
            Text("✅")
                .font(.system(size: 64))
            Text("Done!")
                .font(.title2).bold()
            Text("**\(formattedFreed)** moved to Trash")
                .font(.title3)
            Text("Items are in your Trash — you can empty it or restore them from there.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 40)

            Text("Scan Again")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(Color.accentColor)
                .cornerRadius(10)
                .onTapGesture { appState.startSystemScan() }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
