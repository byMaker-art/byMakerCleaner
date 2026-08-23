import SwiftUI

@main
struct byMakerCleanerApp: App {
    init() {
        // Disable native window tabbing to prevent Kepler GPU (OCLP) Metal crashes 
        // when users trigger "Show All Tabs".
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}

