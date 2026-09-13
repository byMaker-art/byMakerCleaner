import SwiftUI

/// Main window — tab bar with Smart Scan and App Uninstaller.
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var healthService: HealthService
    @Environment(\.openWindow) var openWindow
    @State private var selectedTab: Int = 0

    var body: some View {
        if appState.selectedApp != nil {
            // App detail pushed over the whole window
            AppDetailView()
                .environmentObject(appState)
                .frame(minWidth: 700, minHeight: 500)
                .background(Theme.background)
        } else {
            HStack(spacing: 0) {
                // ── Left Navigation Panel ──────────────────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    Text("[ MAIN SYSTEM ]")
                        .font(Theme.font(size: 16, weight: .bold))
                        .foregroundColor(Theme.accent)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    
                    navLabel(title: "SMART SCAN", tag: 0)
                    navLabel(title: "UNINSTALLER", tag: 1)
                    navLabel(title: "LOGIN ITEMS", tag: 2)
                    navLabel(title: "ORPHAN FINDER", tag: 3)
                    navLabel(title: "MAINTENANCE", tag: 4)
                    
                    Spacer()
                    
                    TerminalCard(title: "HEALTH") {
                        HealthGaugeView(score: healthService.score)
                            .padding(.bottom, 8)
                    }
                    .frame(height: 100)
                }
                .padding(.horizontal, 16)
                .frame(width: 220)
                .background(Theme.surface)
                
                // Vertical divider
                Rectangle()
                    .fill(Theme.border)
                    .frame(width: 1)
                
                // ── Main Content Area ──────────────────────────────────────
                Group {
                    if selectedTab == 0 {
                        CleanerView()
                            .environmentObject(appState)
                    } else if selectedTab == 1 {
                        AppListView()
                            .environmentObject(appState)
                    } else if selectedTab == 2 {
                        LoginItemsView()
                    } else if selectedTab == 3 {
                        OrphanFinderView()
                    } else {
                        MaintenanceView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
            }
            .frame(minWidth: 740, minHeight: 540)
            .background(Theme.background)
            .onOpenURL { url in
                if url.host == "settings" {
                    openWindow(id: "settings")
                }
            }
        }
    }

    private func navLabel(title: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        let color = isSelected ? Theme.accent : Theme.textMuted
        
        return HStack {
            Text(isSelected ? "▶" : " ")
                .foregroundColor(color)
            Text(title)
                .foregroundColor(isSelected ? Theme.textPrimary : Theme.textMuted)
            Spacer()
        }
        .font(Theme.font(size: 14, weight: isSelected ? .bold : .regular))
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture { selectedTab = tag }
    }
}
