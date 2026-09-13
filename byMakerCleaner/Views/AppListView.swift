import SwiftUI

/// App Uninstaller — lists installed apps with size info.
/// UI style matches OrphanFinderView: header bar + list + tap-to-detail.
/// GPU-safe: Text + .onTapGesture only.
struct AppListView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var isUserVerifiedExpanded = true
    @State private var isVerifiedExpanded = true
    @State private var isUnknownExpanded = true

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(Theme.border).frame(height: 1)
            contentArea
        }
        .background(Theme.background)
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
                Text("[ APP UNINSTALLER ]")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text("FIND AND REMOVE INSTALLED APPLICATIONS")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            if !appState.installedApps.isEmpty {
                VStack(alignment: .trailing, spacing: 1) {
                    let knownCount = appState.installedApps.filter { $0.isKnownApp }.count
                    let unknownCount = appState.installedApps.count - knownCount
                    Text("\(appState.installedApps.count) APPS  •  [+] \(knownCount)  [!] \(unknownCount)")
                        .font(Theme.font(size: 12))
                        .foregroundColor(Theme.textMuted)
                    if appState.isRecalculatingSizes {
                        Text("CALCULATING SIZES...")
                            .font(Theme.font(size: 10))
                            .foregroundColor(Theme.textMuted)
                    }
                    if appState.isHeuristicScanning {
                        Text("DEEP SCANNING SELECTED...")
                            .font(Theme.font(size: 10))
                            .foregroundColor(Theme.accent)
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
        let label = appState.isLoadingApps ? "SCANNING..." :
                    appState.isRecalculatingSizes ? "CALCULATING..." :
                    appState.isHeuristicScanning ? "SCANNING..." : "RESCAN"
        
        return TerminalButton(label, icon: "arrow.clockwise") {
            if !isBusy { appState.loadInstalledApps() }
        }
        .opacity(isBusy ? 0.5 : 1.0)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if appState.isLoadingApps && appState.installedApps.isEmpty {
            VStack(spacing: 12) {
                Text("[ SCANNING SYSTEM... ]")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundColor(Theme.accent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appState.installedApps.isEmpty {
            VStack(spacing: 12) {
                Text("[ NO APPLICATIONS FOUND ]")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundColor(Theme.textMuted)
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
                Text("SORT:")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)
                    .padding(.trailing, 4)
                ForEach(AppState.AppSortOrder.allCases, id: \.self) { order in
                    let isActive = appState.appSortOrder == order
                    Text(order.rawValue.uppercased())
                        .font(Theme.font(size: 12, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? Theme.background : Theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isActive ? Theme.accent : Color.clear)
                        .border(isActive ? Theme.accent : Color.clear, width: 1)
                        .onTapGesture { appState.appSortOrder = order }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.surface)

            Rectangle().fill(Theme.border).frame(height: 1)

            // ── Two-section list ─────────────────────────────────────────
            List {
                // ── SECTION 1: User Verified Apps ───────────────────────────
                if !userApps.isEmpty {
                    Section {
                        if isUserVerifiedExpanded {
                            ForEach(userApps) { app in
                                verifiedAppRow(app, isUser: true)
                                    .listRowBackground(Theme.background)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .contentShape(Rectangle())
                                    .onTapGesture { appState.selectApp(app) }
                            }
                        }
                    } header: {
                        HStack {
                            Text(isUserVerifiedExpanded ? "[-]" : "[+]")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text("USER VERIFIED")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text("— SAVED BY YOU")
                                .font(Theme.font(size: 10))
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Text("\(userApps.count)")
                                .font(Theme.font(size: 10))
                                .foregroundColor(Theme.textMuted)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { isUserVerifiedExpanded.toggle() }
                    }
                }

                // ── SECTION 2: Verified Apps (Cask DB) ──────────────────
                if !knownApps.isEmpty {
                    Section {
                        if isVerifiedExpanded {
                            ForEach(knownApps) { app in
                                verifiedAppRow(app, isUser: false)
                                    .listRowBackground(Theme.background)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                    .contentShape(Rectangle())
                                    .onTapGesture { appState.selectApp(app) }
                            }
                        }
                    } header: {
                        HStack {
                            Text(isVerifiedExpanded ? "[-]" : "[+]")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text("VERIFIED APPS")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text("— EXACT PATHS FROM HOMEBREW CASK DB")
                                .font(Theme.font(size: 10))
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            Text("\(knownApps.count)")
                                .font(Theme.font(size: 10))
                                .foregroundColor(Theme.textMuted)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { isVerifiedExpanded.toggle() }
                    }
                }

                // ── SECTION 3: Unknown Apps (needs heuristic) ────────────
                if !unknownApps.isEmpty {
                    Section {
                        if isUnknownExpanded {
                            ForEach(unknownApps) { app in
                                unknownAppRow(app)
                                    .listRowBackground(Theme.background)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            }
                        }
                    } header: {
                        HStack {
                            Text(isUnknownExpanded ? "[-]" : "[+]")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Theme.accent)
                            Text("UNKNOWN APPS")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Theme.accent)
                            Text("— NOT IN CASK DB")
                                .font(Theme.font(size: 10))
                                .foregroundColor(Theme.textMuted)
                            Spacer()
                            // Scan Selected button
                            let selectedCount = unknownApps.filter { $0.selectedForHeuristic }.count
                            if selectedCount > 0 {
                                let busy = appState.isHeuristicScanning
                                Text(busy ? "[ SCANNING... ]" : "[ DEEP SCAN (\(selectedCount)) ]")
                                    .font(Theme.font(size: 10, weight: .bold))
                                    .foregroundColor(busy ? Theme.textMuted : Theme.background)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 3)
                                    .background(busy ? Color.clear : Theme.accent)
                                    .border(busy ? Theme.textMuted : Theme.accent, width: 1)
                                    .onTapGesture {
                                        if !busy { appState.scanSelectedWithHeuristic() }
                                    }
                            }
                            Text("\(unknownApps.count)")
                                .font(Theme.font(size: 10))
                                .foregroundColor(Theme.textMuted)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { isUnknownExpanded.toggle() }
                    }
                }
            }
            .listStyle(.plain)
            .background(Theme.background)
            .scrollContentBackground(.hidden)

            if let pendingApp = appState.pendingUserDBApp {
                userDBBanner(app: pendingApp)
            }
        }
    }

    private func userDBBanner(app: InstalledApp) -> some View {
        HStack(spacing: 12) {
            Text("[+]")
                .font(Theme.font(size: 16, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(app.appName.uppercased()) — \(appState.pendingUserDBPaths?.count ?? 0) FILES FOUND.")
                    .font(Theme.font(size: 14, weight: .bold))
                Text("SAVE TO USER DB TO SKIP DEEP SCAN NEXT TIME.")
                    .font(Theme.font(size: 10))
                    .opacity(0.8)
            }
            Spacer()
            
            Text("[ DISMISS ]")
                .font(Theme.font(size: 10))
                .padding(.trailing, 8)
                .onTapGesture {
                    withAnimation {
                        appState.pendingUserDBApp = nil
                        appState.pendingUserDBPaths = nil
                    }
                }
            
            Text("[ ADD TO DB ]")
                .font(Theme.font(size: 12, weight: .bold))
                .foregroundColor(Theme.success)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .border(Theme.success, width: 1)
                .onTapGesture {
                    if let paths = appState.pendingUserDBPaths {
                        UserDatabase.shared.save(app: app, paths: paths)
                        appState.loadInstalledApps() // reload to apply
                    }
                    withAnimation {
                        appState.pendingUserDBApp = nil
                        appState.pendingUserDBPaths = nil
                    }
                }
        }
        .padding(12)
        .background(Theme.surface)
        .border(Theme.success, width: 1)
        .foregroundColor(Theme.textPrimary)
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
                Text("> " + app.appName.uppercased())
                    .font(Theme.font(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            Text(app.formattedSize)
                .font(Theme.font(size: 12))
                .foregroundColor(Theme.textMuted)
                .frame(width: 64, alignment: .trailing)

            Text("▶")
                .font(Theme.font(size: 10))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(Theme.surface)
        .border(Theme.border, width: 1)
    }

    /// Row for Unknown app — has checkbox + tap opens detail, checkbox toggles heuristic selection
    private func unknownAppRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 10) {
            // Checkbox (GPU-safe: text symbol)
            Text(app.selectedForHeuristic ? "[X]" : "[ ]")
                .font(Theme.font(size: 14))
                .foregroundColor(app.selectedForHeuristic ? Theme.accent : Theme.textMuted)
                .fixedSize()
                .onTapGesture { appState.toggleHeuristicSelection(for: app) }

            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("? " + app.appName.uppercased())
                    .font(Theme.font(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
            .onTapGesture { appState.selectApp(app) }

            Spacer()

            Text(app.formattedSize)
                .font(Theme.font(size: 12))
                .foregroundColor(Theme.textMuted)
                .frame(width: 64, alignment: .trailing)

            Text("▶")
                .font(Theme.font(size: 10))
                .foregroundColor(Theme.textMuted)
                .onTapGesture { appState.selectApp(app) }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, 8)
        .background(app.selectedForHeuristic ? Theme.surface : Color.clear)
        .border(Theme.border, width: 1)
    }
}
