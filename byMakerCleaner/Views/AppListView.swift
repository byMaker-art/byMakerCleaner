import SwiftUI

/// App Uninstaller — lists installed apps with size info.
/// UI style matches OrphanFinderView: header bar + list + tap-to-detail.
/// GPU-safe: Text + .onTapGesture only.
struct AppListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
        }
        .onAppear {
            if appState.installedApps.isEmpty {
                appState.loadInstalledApps()
            }
        }
    }


    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("📱 App Uninstaller")
                    .font(.headline)
                Text("Find and remove installed applications")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !appState.installedApps.isEmpty {
                VStack(alignment: .trailing, spacing: 1) {
                    let knownCount = appState.installedApps.filter { $0.isKnownApp }.count
                    let unknownCount = appState.installedApps.count - knownCount
                    Text("\(appState.installedApps.count) apps  •  ✅ \(knownCount)  ⚠️ \(unknownCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if appState.isRecalculatingSizes {
                        Text("calculating sizes...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    if appState.isHeuristicScanning {
                        Text("deep scanning selected...")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
            rescanButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var rescanButton: some View {
        let isBusy = appState.isLoadingApps || appState.isRecalculatingSizes || appState.isHeuristicScanning
        let label = appState.isLoadingApps ? "Scanning..." :
                    appState.isRecalculatingSizes ? "Calculating..." :
                    appState.isHeuristicScanning ? "Scanning..." : "Rescan"
        return Text(label)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isBusy ? .secondary : .accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(isBusy ? 0.05 : 0.12))
            .cornerRadius(6)
            .onTapGesture { if !isBusy { appState.loadInstalledApps() } }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if appState.isLoadingApps && appState.installedApps.isEmpty {
            VStack(spacing: 12) {
                Text("🔍").font(.system(size: 40))
                Text("Looking for installed apps...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appState.installedApps.isEmpty {
            VStack(spacing: 12) {
                Text("📭").font(.system(size: 40))
                Text("No applications found.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            appList
        }
    }

    // MARK: - App list

    private var userApps: [InstalledApp] {
        appState.sortedInstalledApps.filter { $0.isUserDB }
    }
    private var knownApps: [InstalledApp] {
        appState.sortedInstalledApps.filter { $0.isKnownApp && !$0.isUserDB }
    }
    private var unknownApps: [InstalledApp] {
        appState.sortedInstalledApps.filter { !$0.isKnownApp }
    }

    private var appList: some View {
        VStack(spacing: 0) {
            // ── Toolbar ─────────────────────────────────────────────────
            HStack(spacing: 0) {
                Spacer()
                Text("Sort:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
                ForEach(AppState.AppSortOrder.allCases, id: \.self) { order in
                    let isActive = appState.appSortOrder == order
                    Text(order.rawValue)
                        .font(.caption)
                        .fontWeight(isActive ? .bold : .regular)
                        .foregroundColor(isActive ? .accentColor : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                        .onTapGesture { appState.appSortOrder = order }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // ── Two-section list ─────────────────────────────────────────
            List {
                // ── SECTION 1: User Verified Apps ───────────────────────────
                if !userApps.isEmpty {
                    Section {
                        ForEach(userApps) { app in
                            verifiedAppRow(app, isUser: true)
                                .listRowSeparator(.visible)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .contentShape(Rectangle())
                                .onTapGesture { appState.selectApp(app) }
                        }
                    } header: {
                        HStack {
                            Text("👤  User Verified")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text("— saved by you")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(userApps.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── SECTION 2: Verified Apps (Cask DB) ──────────────────
                if !knownApps.isEmpty {
                    Section {
                        ForEach(knownApps) { app in
                            verifiedAppRow(app, isUser: false)
                                .listRowSeparator(.visible)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .contentShape(Rectangle())
                                .onTapGesture { appState.selectApp(app) }
                        }
                    } header: {
                        HStack {
                            Text("✅  Verified Apps")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text("— exact paths from Homebrew Cask DB")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(knownApps.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }

                // ── SECTION 3: Unknown Apps (needs heuristic) ────────────
                if !unknownApps.isEmpty {
                    Section {
                        ForEach(unknownApps) { app in
                            unknownAppRow(app)
                                .listRowSeparator(.visible)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        }
                    } header: {
                        HStack {
                            Text("⚠️  Unknown Apps")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                            Text("— not in Cask DB")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            // Scan Selected button
                            let selectedCount = unknownApps.filter { $0.selectedForHeuristic }.count
                            if selectedCount > 0 {
                                let busy = appState.isHeuristicScanning
                                Text(busy ? "Scanning..." : "Deep Scan (\(selectedCount))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(busy ? .secondary : .orange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(busy ? 0.05 : 0.12))
                                    .cornerRadius(5)
                                    .onTapGesture {
                                        if !busy { appState.scanSelectedWithHeuristic() }
                                    }
                            }
                            Text("\(unknownApps.count)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)

            if let pendingApp = appState.pendingUserDBApp {
                userDBBanner(app: pendingApp)
            }
        }
    }

    private func userDBBanner(app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            Text("💾")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(app.appName) — \(appState.pendingUserDBPaths?.count ?? 0) files found.")
                    .font(.subheadline)
                    .bold()
                Text("Save to your DB to skip deep scan next time.")
                    .font(.caption)
                    .opacity(0.8)
            }
            Spacer()
            
            Button("Dismiss") {
                withAnimation {
                    appState.pendingUserDBApp = nil
                    appState.pendingUserDBPaths = nil
                }
            }
            .buttonStyle(.plain)
            .font(.caption)
            .padding(.trailing, 8)
            
            Button("Add to My Database") {
                if let paths = appState.pendingUserDBPaths {
                    UserDatabase.shared.save(app: app, paths: paths)
                    appState.loadInstalledApps() // reload to apply
                }
                withAnimation {
                    appState.pendingUserDBApp = nil
                    appState.pendingUserDBPaths = nil
                }
            }
            .buttonStyle(.plain)
            .font(.subheadline)
            .bold()
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.2))
            .cornerRadius(6)
        }
        .padding(12)
        .background(Color.green.opacity(0.9))
        .foregroundColor(.white)
        .transition(.move(edge: .bottom))
    }

    // MARK: - Row views

    /// Row for Verified app (green checkmark or user profile, tap to uninstall)
    private func verifiedAppRow(_ app: InstalledApp, isUser: Bool) -> some View {
        HStack(spacing: 10) {
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(app.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)

            Text("›")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    /// Row for Unknown app — has checkbox + tap opens detail, checkbox toggles heuristic selection
    private func unknownAppRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 10) {
            // Checkbox (GPU-safe: text symbol)
            Text(app.selectedForHeuristic ? "☑" : "☐")
                .font(.system(size: 18))
                .foregroundColor(app.selectedForHeuristic ? .orange : .secondary)
                .frame(width: 24)
                .onTapGesture { appState.toggleHeuristicSelection(for: app) }

            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture { appState.selectApp(app) }

            Spacer()

            Text(app.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)

            Text("›")
                .font(.title3)
                .foregroundColor(.secondary)
                .onTapGesture { appState.selectApp(app) }
        }
        .padding(.vertical, 2)
    }
}
