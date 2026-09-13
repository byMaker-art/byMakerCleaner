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

    // MARK: - User DB Banner state
    @Published var pendingUserDBApp: InstalledApp? = nil
    @Published var pendingUserDBPaths: [URL]? = nil

    enum AppSortOrder: String, CaseIterable {
        case name = "Name"
        case size = "Size"
    }
    @Published var appSortOrder: AppSortOrder = .name

    var sortedInstalledApps: [InstalledApp] {
        switch appSortOrder {
        case .name:
            return installedApps.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }
        case .size:
            return installedApps.sorted { $0.size > $1.size }
        }
    }

    // MARK: - System Cleaner state

    @Published var scanState: ScanState = .idle
    @Published var categoryResults: [CategoryResult] = []
    @Published var currentScanPath: String = ""

    private let scanEngine = SystemScanEngine()
    private var scanTask: Task<Void, Never>?

    init() {}

    // MARK: - App Uninstaller methods

    // True while Cask sizes are being computed via Glob.expand().
    @Published var isRecalculatingSizes: Bool = false
    // True while heuristic scan runs for selected Unknown apps.
    @Published var isHeuristicScanning: Bool = false

    func loadInstalledApps() {
        guard !isLoadingApps else { return }
        isLoadingApps = true

        Task {
            // Step 1 — fast load: AppInfoFetcher already marks each app as
            // isKnownApp=true/false and stores caskPaths from CaskDatabase.
            let apps = await Task.detached(priority: .userInitiated) {
                AppInfoFetcher.shared.fetchInstalledApps()
            }.value
            self.installedApps = apps
            self.isLoadingApps = false

            // Step 2 — for Cask-known apps only: expand glob paths and
            // compute the real total size. This is fast (no disk walk needed,
            // only stat() on already-known paths).
            self.isRecalculatingSizes = true
            let caskApps = apps.filter { $0.isKnownApp }
            let recalculated: [(UUID, Int64)] = await Task.detached(priority: .userInitiated) {
                await withTaskGroup(of: (UUID, Int64).self) { group in
                    for app in caskApps {
                        group.addTask { [app] in
                            guard let rawPaths = app.dbPaths else { return (app.id, app.size) }
                            // Expand ~ and glob wildcards to real filesystem URLs
                            let expandedURLs = [app.path] + rawPaths.flatMap { Glob.expand($0) }
                            let total = expandedURLs.reduce(Int64(0)) { acc, url in
                                acc + (FileSizeCalculator.size(of: url) ?? 0)
                            }
                            return (app.id, max(total, app.size))
                        }
                    }
                    var results: [(UUID, Int64)] = []
                    for await pair in group { results.append(pair) }
                    return results
                }
            }.value

            let sizeMap = Dictionary(uniqueKeysWithValues: recalculated)
            for i in self.installedApps.indices {
                if let newSize = sizeMap[self.installedApps[i].id] {
                    self.installedApps[i].size = newSize
                }
            }
            self.isRecalculatingSizes = false
        }
    }

    /// Toggle heuristic selection for an Unknown app.
    func toggleHeuristicSelection(for app: InstalledApp) {
        guard let idx = installedApps.firstIndex(of: app) else { return }
        installedApps[idx].selectedForHeuristic.toggle()
    }

    /// Run AppPathFinder heuristic scan for all Unknown apps that are
    /// currently selected (selectedForHeuristic == true).
    func scanSelectedWithHeuristic() {
        guard !isHeuristicScanning else { return }
        let selected = installedApps.filter { !$0.isKnownApp && $0.selectedForHeuristic }
        guard !selected.isEmpty else { return }

        isHeuristicScanning = true
        Task {
            let results: [(UUID, Int64, [URL])] = await Task.detached(priority: .userInitiated) {
                let locations = Locations()
                return await withTaskGroup(of: (UUID, Int64, [URL]).self) { group in
                    for app in selected {
                        group.addTask { [locations, app] in
                            let paths = AppPathFinder(appInfo: app, locations: locations).findPaths()
                            let total = paths.reduce(Int64(0)) { acc, url in
                                acc + (FileSizeCalculator.size(of: url) ?? 0)
                            }
                            return (app.id, max(total, app.size), Array(paths))
                        }
                    }
                    var results: [(UUID, Int64, [URL])] = []
                    for await pair in group { results.append(pair) }
                    return results
                }
            }.value

            for i in self.installedApps.indices {
                if let res = results.first(where: { $0.0 == self.installedApps[i].id }) {
                    self.installedApps[i].size = res.1
                    // Mark as scanned — clear selection after scan
                    self.installedApps[i].selectedForHeuristic = false
                }
            }
            
            if selected.count == 1, let firstRes = results.first, let app = selected.first {
                self.pendingUserDBApp = app
                self.pendingUserDBPaths = firstRes.2
            } else {
                self.pendingUserDBApp = nil
                self.pendingUserDBPaths = nil
            }
            
            self.isHeuristicScanning = false
        }
    }

    func selectApp(_ app: InstalledApp?) {
        self.selectedApp = app
        self.selectedAppJunkPaths = []

        guard let app = app else { return }
        isScanningJunk = true

        Task {
            let paths: Set<URL>
            if let rawPaths = app.dbPaths {
                // Known app: resolve exact Cask paths via Glob (fast, no disk walk)
                paths = Set([app.path] + rawPaths.flatMap { Glob.expand($0) })
            } else {
                // Unknown app: fall back to full heuristic scan
                paths = await Task.detached(priority: .userInitiated) {
                    AppPathFinder(appInfo: app, locations: Locations()).findPaths()
                }.value
            }
            self.selectedAppJunkPaths = Array(paths).sorted(by: { $0.path < $1.path })
            self.isScanningJunk = false
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

    /// Clean selected items:
    /// - trashBins items are already in ~/.Trash → delete them permanently (removeItem)
    /// - all other items → move to Trash safely (trashItem)
    func cleanSelectedItems() {
        let itemsToClean = categoryResults.flatMap { $0.items }.filter { $0.isSelected && !$0.path.isEmpty }
        guard !itemsToClean.isEmpty else { return }

        scanState = .cleaning
        let totalBytes = itemsToClean.reduce(0) { $0 + $1.size }
        let hasTrashItems = itemsToClean.contains { $0.category == .trashBins }

        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            for item in itemsToClean {
                let url = URL(fileURLWithPath: item.path)
                if item.category == .trashBins {
                    // Items inside ~/.Trash are already in Trash — delete permanently
                    try? fm.removeItem(at: url)
                } else {
                    do {
                        try fm.trashItem(at: url, resultingItemURL: nil)
                    } catch {
                        // Fallback: direct removal (e.g. /private/var/tmp items)
                        try? fm.removeItem(at: url)
                    }
                }
            }
            await MainActor.run {
                self.categoryResults = []
                self.scanState = .cleanDone(freedBytes: totalBytes, hasTrashItems: hasTrashItems)
            }
        }
    }
}
