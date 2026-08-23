import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var installedApps: [InstalledApp] = []
    @Published var isLoadingApps: Bool = false
    
    @Published var selectedApp: InstalledApp? = nil
    @Published var selectedAppJunkPaths: [URL] = []
    @Published var isScanningJunk: Bool = false
    
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
    
    func selectApp(_ app: InstalledApp?) {
        self.selectedApp = app
        self.selectedAppJunkPaths = []
        
        if let app = app {
            isScanningJunk = true
            Task {
                let paths = await Task.detached(priority: .userInitiated) {
                    AppPathFinder(appInfo: app, locations: Locations()).findPaths()
                }.value
                
                self.selectedAppJunkPaths = Array(paths).sorted(by: { $0.path < $1.path })
                self.isScanningJunk = false
            }
        }
    }
    
    func deleteSelectedApp() {
        guard let app = selectedApp else { return }
        
        let fileManager = FileManager.default
        var allPathsToDelete = selectedAppJunkPaths
        allPathsToDelete.append(app.path) // Also delete the .app bundle itself
        
        for path in allPathsToDelete {
            do {
                try fileManager.trashItem(at: path, resultingItemURL: nil)
            } catch {
                print("Failed to trash \(path.path): \(error)")
                // Fallback to direct remove if trash fails (e.g. some network drives or permissions)
                try? fileManager.removeItem(at: path)
            }
        }
        
        // After deletion, refresh the list and go back
        selectApp(nil)
        loadInstalledApps()
    }
}
