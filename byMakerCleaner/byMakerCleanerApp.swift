import SwiftUI

@main
struct byMakerCleanerApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            AppListView()
                .environmentObject(appState)
        }
    }
}
