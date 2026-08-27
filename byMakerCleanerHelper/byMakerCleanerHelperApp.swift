import SwiftUI
import Combine

@main
struct byMakerCleanerHelperApp: App {
    @StateObject private var metricsService = SystemMetricsService()
    @StateObject private var settings = GeneralSettings.shared

    // Tracks Combine subscriptions
    @State private var cancellables: Set<AnyCancellable> = []

    var body: some Scene {
        // MenuBarExtra: a native macOS menu bar icon with a popover (macOS 13+)
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(metricsService)
                .environmentObject(settings)
                .onAppear {
                    metricsService.start()
                    // Restart timer whenever the user changes the interval in Settings
                    settings.$metricsInterval
                        .dropFirst()          // Skip initial value
                        .debounce(for: 0.2, scheduler: RunLoop.main)
                        .sink { [weak metricsService] _ in
                            metricsService?.restart()
                        }
                        .store(in: &cancellables)
                }
                .onDisappear { metricsService.stop() }
        } label: {
            Label("byMaker", systemImage: "sparkles")
        }
        .menuBarExtraStyle(.window)
    }
}

