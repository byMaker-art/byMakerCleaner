import SwiftUI

@main
struct byMakerCleanerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            if appState.selectedApp != nil {
                AppDetailView()
                    .environmentObject(appState)
            } else {
                AppListView()
                    .environmentObject(appState)
            }
        }
    }
}
