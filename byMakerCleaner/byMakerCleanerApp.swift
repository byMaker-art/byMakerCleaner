import SwiftUI
import Combine

@main
struct byMakerCleanerApp: App {
    init() {
        // Disable native window tabbing to prevent Kepler GPU (OCLP) Metal crashes
        // when users trigger "Show All Tabs".
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    @StateObject private var appState = AppState()
    @StateObject private var metricsService = SystemMetricsService()
    @StateObject private var bluetoothService = BluetoothService()
    @StateObject private var healthService = HealthService()
    // GeneralSettings is a singleton — use the shared instance directly
    private let settings = GeneralSettings.shared

    // Stores Combine subscriptions for interval observer
    @State private var cancellables: Set<AnyCancellable> = []

    var body: some Scene {
        // ── Main window ──────────────────────────────────────────────────────
        Window("byMaker Cleaner", id: "main") {
            ContentView()
                .environmentObject(appState)
                .environmentObject(healthService)
                .background(Theme.background)
                .onAppear {
                    CaskDatabaseUpdater.shared.checkAgeAndNotifyIfNeeded()
                }
                .onOpenURL { url in
                    // Handle bymakercleaner://settings deep-link (future use / Shortcuts)
                    if url.host == "settings" {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)

        // ── Menu Bar Tray Widget (merged from Helper) ─────────────────────
        MenuBarExtra {
            MenuBarPopoverView()
                .environmentObject(metricsService)
                .environmentObject(bluetoothService)
                .environmentObject(healthService)
                .environmentObject(settings)
                .onAppear {
                    metricsService.start()
                    // Restart timer when user changes interval in Settings
                    settings.$metricsInterval
                        .dropFirst()
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

        // ── Settings window (Cmd+,) ──────────────────────────────────────
        Settings {
            GeneralSettingsView()
                .background(Theme.background)
        }
        .windowStyle(.hiddenTitleBar)
    }
}
