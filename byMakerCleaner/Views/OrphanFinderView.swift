import SwiftUI

/// Tab: Orphan Finder — scans for leftover files from uninstalled applications.
/// GPU-safe: uses only Text + .onTapGesture (no Button, no Toggle).
struct OrphanFinderView: View {
    @StateObject private var vm = OrphanFinderViewModel()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
            if vm.scanState == .done && !vm.rawFiles.isEmpty {
                Divider()
                actionBar
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("🔍 Orphan Finder")
                    .font(.headline)
                Text("Leftovers from uninstalled apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !vm.statusMessage.isEmpty {
                Text(vm.statusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            scanButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var scanButton: some View {
        let isScanning = vm.scanState == .scanning
        return Text(isScanning ? "Scanning..." : "Scan")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isScanning ? .secondary : .accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(isScanning ? 0.05 : 0.12))
            .cornerRadius(6)
            .onTapGesture { if !isScanning { vm.startScan() } }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch vm.scanState {
        case .idle:    idlePlaceholder
        case .scanning: scanningView
        case .done:
            if vm.rawFiles.isEmpty { emptyView } else { resultsList }
        }
    }

    private var idlePlaceholder: some View {
        VStack(spacing: 12) {
            Text("🧹").font(.system(size: 40))
            Text("Press Scan to find leftover files\nfrom apps you've already uninstalled.")
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var scanningView: some View {
        VStack(spacing: 12) {
            Text("🔍").font(.system(size: 40))
            Text("Scanning Library directories...")
                .font(.subheadline).foregroundColor(.secondary)
            Text("This may take a few seconds")
                .font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Text("✅").font(.system(size: 40))
            Text("No orphan files found — your Library is clean!")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Results list

    private var resultsList: some View {
        VStack(spacing: 0) {
            // ── Toolbar ─────────────────────────────────────────────────
            HStack(spacing: 0) {
                // Selection info
                Text(vm.selectedCount == 0
                     ? "\(vm.rawFiles.count) item(s) found"
                     : "\(vm.selectedCount) selected — \(vm.selectedTotalSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 160, alignment: .leading)

                Spacer()

                // Sort buttons
                Text("Sort:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)

                ForEach(OrphanFinderViewModel.SortOrder.allCases, id: \.self) { order in
                    let isActive = vm.sortOrder == order
                    Text(order.rawValue)
                        .font(.caption)
                        .fontWeight(isActive ? .bold : .regular)
                        .foregroundColor(isActive ? .accentColor : .secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isActive ? Color.accentColor.opacity(0.12) : Color.clear)
                        .onTapGesture { vm.sortOrder = order }
                }

                Text("  |  ")
                    .font(.caption)
                    .foregroundColor(Color.secondary.opacity(0.4))

                // Select/Deselect
                Text("Select All")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .onTapGesture { vm.selectAll() }

                Text("  ·  ")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Deselect All")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .onTapGesture { vm.deselectAll() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // ── List ────────────────────────────────────────────────────
            List(vm.sortedFiles) { file in
                orphanRow(file)
                    .listRowSeparator(.visible)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .listStyle(.plain)
        }
    }

    private func orphanRow(_ file: OrphanFile) -> some View {
        let isSelected = vm.selectedItems.contains(file.id)
        return HStack(spacing: 8) {
            // Emoji checkbox (GPU-safe)
            Text(isSelected ? "☑" : "☐")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .onTapGesture { vm.toggleSelection(file.id) }

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(compactPath(file.path))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            .onTapGesture { vm.toggleSelection(file.id) }

            Spacer()

            // Date (shown when sorting by date)
            if vm.sortOrder == .date {
                Text(formattedDate(file.dateModified))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 70, alignment: .trailing)
            }

            // Size
            Text(file.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)

            // Reveal in Finder
            Text("Finder")
                .font(.caption)
                .foregroundColor(.accentColor)
                .onTapGesture { vm.revealInFinder(file.url) }
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Text(vm.selectedCount == 0
                 ? "Select items above to delete"
                 : "\(vm.selectedCount) selected — \(vm.selectedTotalSize)")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(vm.isDeleting ? "Moving to Trash..." : "Move to Trash")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(vm.selectedCount == 0 || vm.isDeleting ? .secondary : .red)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.red.opacity(vm.selectedCount == 0 ? 0.0 : 0.08))
                .onTapGesture {
                    if vm.selectedCount > 0 && !vm.isDeleting { vm.trashSelected() }
                }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Helpers

    private func compactPath(_ path: String) -> String {
        path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }

    private func formattedDate(_ date: Date) -> String {
        guard date != .distantPast else { return "—" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        return f.string(from: date)
    }
}
