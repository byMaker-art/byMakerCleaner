import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {

    // MARK: - App Uninstaller state

    @Published var installedApps: [InstalledApp] = []
    @Published var isLoadingApps: Bool = false

    @Published var selectedApp: InstalledApp? = nil
    @Published var selectedAppJunkPaths: [URL] = []
    @Published var isScanningJunk: Bool = false

    // MARK: - System Cleaner state

    @Published var scanState: ScanState = .idle
    @Published var categoryResults: [CategoryResult] = []
    @Published var currentScanPath: String = ""

    private let scanEngine = SystemScanEngine()
    private var scanTask: Task<Void, Never>?

    init() {}

    // MARK: - App Uninstaller methods

    func loadInstalledApps() {
        guard !isLoadingApps else { return }
        isLoadingApps = true

        Task {
            let apps = await Task.detached(priority: .userInitiated) {
                AppInfoFetcher.shared.fetchInstalledApps()
            }.value
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
        allPathsToDelete.append(app.path)

        for path in allPathsToDelete {
            do {
                try fileManager.trashItem(at: path, resultingItemURL: nil)
            } catch {
                print("Failed to trash \(path.path): \(error)")
                try? fileManager.removeItem(at: path)
            }
        }
        selectApp(nil)
        loadInstalledApps()
    }

    // MARK: - System Cleaner methods

    /// Start a full Smart Scan across all categories (parallel)
    func startSystemScan() {
        scanTask?.cancel()
        categoryResults = []
        scanState = .scanning(currentPath: "")
        currentScanPath = ""

        scanTask = Task {
            let categories = CleaningCategory.allCases
            // Run all categories concurrently
            await withTaskGroup(of: CategoryResult.self) { group in
                for category in categories {
                    group.addTask {
                        await self.scanEngine.scanCategory(category) { path in
                            Task { @MainActor in
                                self.currentScanPath = path
                                self.scanState = .scanning(currentPath: path)
                            }
                        }
                    }
                }
                var results: [CategoryResult] = []
                for await result in group {
                    if Task.isCancelled { break }
                    results.append(result)
                }
                // Sort results to match category order
                let ordered = categories.compactMap { cat in results.first { $0.category == cat } }
                await MainActor.run {
                    self.categoryResults = ordered
                    self.scanState = .done
                }
            }
        }
    }

    func cancelSystemScan() {
        scanTask?.cancel()
        scanState = .idle
    }

    /// Toggle selection of a single item
    func toggleItem(_ item: CleanableItem, inCategory category: CleaningCategory) {
        guard let catIdx = categoryResults.firstIndex(where: { $0.category == category }),
              let itemIdx = categoryResults[catIdx].items.firstIndex(where: { $0.id == item.id })
        else { return }
        categoryResults[catIdx].items[itemIdx].isSelected.toggle()
    }

    /// Toggle all items in a category
    func toggleCategory(_ category: CleaningCategory) {
        guard let catIdx = categoryResults.firstIndex(where: { $0.category == category }) else { return }
        let allSelected = categoryResults[catIdx].items.allSatisfy { $0.isSelected }
        for idx in categoryResults[catIdx].items.indices {
            categoryResults[catIdx].items[idx].isSelected = !allSelected
        }
    }

    /// Total size of all currently selected items
    var totalSelectedSize: Int64 {
        categoryResults.flatMap { $0.items }.filter { $0.isSelected }.reduce(0) { $0 + $1.size }
    }

    var totalSelectedSizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalSelectedSize, countStyle: .file)
    }

    var hasSelectedItems: Bool {
        categoryResults.flatMap { $0.items }.contains { $0.isSelected }
    }

    /// Move selected items to Trash (safe — uses trashItem, never direct delete)
    func cleanSelectedItems() {
        let itemsToClean = categoryResults.flatMap { $0.items }.filter { $0.isSelected && !$0.path.isEmpty }
        guard !itemsToClean.isEmpty else { return }

        scanState = .cleaning
        let totalBytes = itemsToClean.reduce(0) { $0 + $1.size }

        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            for item in itemsToClean {
                let url = URL(fileURLWithPath: item.path)
                do {
                    try fm.trashItem(at: url, resultingItemURL: nil)
                } catch {
                    // Fallback: direct removal (e.g. /tmp items that can't go to Trash)
                    try? fm.removeItem(at: url)
                }
            }
            await MainActor.run {
                self.categoryResults = []
                self.scanState = .cleanDone(freedBytes: totalBytes)
            }
        }
    }
}
