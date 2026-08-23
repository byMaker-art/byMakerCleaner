import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var installedApps: [InstalledApp] = []
    @Published var isLoadingApps: Bool = false
    
    init() {}
    
    func loadInstalledApps() {
        guard !isLoadingApps else { return }
        isLoadingApps = true
        
        Task {
            // Run the scan in the background
            let apps = await Task.detached(priority: .userInitiated) {
                AppInfoFetcher.shared.fetchInstalledApps()
            }.value
            
            // Update the UI on the MainActor
            self.installedApps = apps.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
            self.isLoadingApps = false
        }
    }
}
