import SwiftUI

@main
struct byMakerCleanerHelperApp: App {
    @StateObject private var metricsService = SystemMetricsService()

    var body: some Scene {
        // MenuBarExtra: a native macOS menu bar icon with a popover (macOS 13+)
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(metricsService)
                .onAppear { metricsService.start() }
                .onDisappear { metricsService.stop() }
        } label: {
            Label("byMaker", systemImage: "sparkles")
        }
        .menuBarExtraStyle(.window)
    }
}
