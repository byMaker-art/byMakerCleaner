import SwiftUI

/// ViewModel for the Orphan Finder tab.
@MainActor
final class OrphanFinderViewModel: ObservableObject {

    // MARK: - State

    enum ScanState { case idle, scanning, done }

    enum SortOrder: String, CaseIterable {
        case size        = "Size"
        case name        = "Name"
        case date        = "Date"
    }

    @Published var scanState: ScanState = .idle
    @Published var rawFiles: [OrphanFile] = []          // Unsorted master list
    @Published var selectedItems: Set<UUID> = []
    @Published var statusMessage: String = ""
    @Published var isDeleting: Bool = false
    @Published var sortOrder: SortOrder = .size

    private let engine = OrphanFinderEngine()

    // MARK: - Derived: sorted list

    var sortedFiles: [OrphanFile] {
        switch sortOrder {
        case .size: return rawFiles.sorted { $0.size > $1.size }
        case .name: return rawFiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .date: return rawFiles.sorted { $0.dateModified > $1.dateModified }
        }
    }

    // MARK: - Scan

    func startScan() {
        guard scanState != .scanning else { return }
        scanState = .scanning
        statusMessage = "Scanning for orphan files..."
        selectedItems = []
        rawFiles = []

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let installedBundleIDs = await self.engine.fetchInstalledBundleIDs()
            let scanResult = await self.engine.scan(installedBundleIDs: installedBundleIDs)
            await MainActor.run {
                self.rawFiles = scanResult.files
                self.scanState = .done
                if scanResult.files.isEmpty {
                    self.statusMessage = "No orphan files found — your Library is clean! 🎉"
                } else {
                    let totalSize = ByteCountFormatter.string(
                        fromByteCount: scanResult.totalSize, countStyle: .file)
                    self.statusMessage = "Found \(scanResult.files.count) orphan(s) — \(totalSize)"
                }
            }
        }
    }

    // MARK: - Selection helpers

    func toggleSelection(_ id: UUID) {
        if selectedItems.contains(id) { selectedItems.remove(id) } else { selectedItems.insert(id) }
    }

    func selectAll() { selectedItems = Set(rawFiles.map { $0.id }) }
    func deselectAll() { selectedItems = [] }

    var selectedCount: Int { selectedItems.count }
    var selectedTotalSize: String {
        let bytes = rawFiles.filter { selectedItems.contains($0.id) }.reduce(0) { $0 + $1.size }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    // MARK: - Trash

    func trashSelected() {
        guard !selectedItems.isEmpty else { return }
        isDeleting = true
        let toDelete = rawFiles.filter { selectedItems.contains($0.id) }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            var errors: [String] = []
            for file in toDelete {
                do {
                    try FileManager.default.trashItem(at: file.url, resultingItemURL: nil)
                } catch {
                    errors.append(file.name)
                }
            }
            await MainActor.run {
                self.rawFiles.removeAll { self.selectedItems.contains($0.id) }
                self.selectedItems = []
                self.isDeleting = false
                if errors.isEmpty {
                    self.statusMessage = "Moved to Trash: \(toDelete.count) item(s) ✓"
                } else {
                    self.statusMessage = "Done. Could not trash: \(errors.joined(separator: ", "))"
                }
            }
        }
    }

    // MARK: - Finder

    func revealInFinder(_ url: URL) {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }
}
