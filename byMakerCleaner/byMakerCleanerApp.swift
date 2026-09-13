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
                .environmentObject(metricsService)
                .background(Theme.background)
                .onAppear {
                    metricsService.start()
                    CaskDatabaseUpdater.shared.checkAgeAndNotifyIfNeeded()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            AppCommands()
        }

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
        Window("byMakerCleaner Settings", id: "settings") {
            GeneralSettingsView()
                .background(Theme.background)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)

        // ── About window ─────────────────────────────────────────────────
        Window("About byMaker Cleaner", id: "about") {
            AboutView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

struct AppCommands: Commands {
    @Environment(\.openWindow) var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                openWindow(id: "settings")
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .appInfo) {
            Button("About byMaker Cleaner") {
                openWindow(id: "about")
            }
        }
    }
}
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
            
            VStack(spacing: 4) {
                Text("[ BYMAKER CLEANER ]")
                    .font(Theme.font(size: 18, weight: .bold))
                    .foregroundColor(Theme.accent)
                
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("VERSION \(version)")
                        .font(Theme.font(size: 12))
                        .foregroundColor(Theme.textPrimary)
                }
            }
            
            Text("A RETRO-FUTURISTIC MACOS MAINTENANCE TOOL.")
                .font(Theme.font(size: 10))
                .foregroundColor(Theme.textMuted)
                .multilineTextAlignment(.center)
            
            Text("© \(Calendar.current.component(.year, from: Date())) BYMAKER. ALL RIGHTS RESERVED.")
                .font(Theme.font(size: 9))
                .foregroundColor(Theme.textMuted)
                .padding(.top, 10)
        }
        .padding(30)
        .frame(width: 320)
        .background(Theme.background)
    }
}
