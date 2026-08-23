import SwiftUI

/// Main window — tab bar with Smart Scan and App Uninstaller.
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: Int = 0

    var body: some View {
        if appState.selectedApp != nil {
            // App detail pushed over the whole window
            AppDetailView()
                .environmentObject(appState)
                .frame(minWidth: 540, minHeight: 440)
        } else {
            VStack(spacing: 0) {
                // ── Tab Bar ─────────────────────────────────────────
                HStack(spacing: 0) {
                    tabLabel(title: "🧹 Smart Scan", tag: 0)
                    tabLabel(title: "📱 App Uninstaller", tag: 1)
                    Spacer()
                }
                .background(Color(NSColor.windowBackgroundColor))

                Divider()

                // ── Tab Content ─────────────────────────────────────
                Group {
                    if selectedTab == 0 {
                        CleanerView()
                            .environmentObject(appState)
                    } else {
                        AppListView()
                            .environmentObject(appState)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minWidth: 540, minHeight: 460)
        }
    }

    private func tabLabel(title: String, tag: Int) -> some View {
        let isSelected = selectedTab == tag
        return Text(title)
            .font(.subheadline)
            .fontWeight(isSelected ? .bold : .regular)
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            .onTapGesture { selectedTab = tag }
    }
}
