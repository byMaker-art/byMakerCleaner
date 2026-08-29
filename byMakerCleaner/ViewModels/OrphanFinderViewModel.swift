import SwiftUI

/// ViewModel for the Orphan Finder tab.
@MainActor
final class OrphanFinderViewModel: ObservableObject {

    // MARK: - State

    enum ScanState { case idle, buildingMap, scanning, done }

    enum SortOrder: String, CaseIterable {
        case size = "Size"
        case name = "Name"
        case date = "Date"
    }

    @Published var scanState: ScanState = .idle
    @Published var rawFiles: [OrphanFile] = []
    @Published var selectedItems: Set<UUID> = []
    @Published var statusMessage: String = ""
    @Published var isDeleting: Bool = false
    @Published var sortOrder: SortOrder = .size
    /// Progress of Pass 1 (0.0 – 1.0). Used to drive a progress indicator.
    @Published var mapProgress: Double = 0.0

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
        guard scanState != .buildingMap && scanState != .scanning else { return }
        scanState = .buildingMap
        statusMessage = "Analysing installed apps..."
        selectedItems = []
        rawFiles = []
        mapProgress = 0.0

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // Progress callback runs on background thread — bounce to MainActor.
            let progressHandler: @Sendable (Int, Int) -> Void = { [weak self] processed, total in
                guard let self else { return }
                let fraction = total > 0 ? Double(processed) / Double(total) : 0.0
                Task { @MainActor in
                    self.mapProgress = fraction
                    self.statusMessage = "Building app map: \(processed)/\(total)..."
                }
            }

            // Pass 1 + Pass 2 happen inside engine.scan()
            await MainActor.run {
                self.scanState = .scanning
                self.statusMessage = "Scanning for orphan files..."
            }

            let scanResult = await self.engine.scan(progressHandler: progressHandler)

            await MainActor.run {
                self.rawFiles = scanResult.files
                self.scanState = .done
                self.mapProgress = 1.0
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
