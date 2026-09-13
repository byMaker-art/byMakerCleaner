import SwiftUI

/// Tab: Orphan Finder — scans for leftover files from uninstalled applications.
/// GPU-safe: uses only Text + .onTapGesture (no Button, no Toggle).
struct OrphanFinderView: View {
    @StateObject private var vm = OrphanFinderViewModel()

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(Theme.border).frame(height: 1)
            contentArea
            if vm.scanState == .done && !vm.rawFiles.isEmpty {
                Rectangle().fill(Theme.border).frame(height: 1)
                actionBar
            }
        }
        .background(Theme.background)
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("[ ORPHAN FINDER ]")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundColor(Theme.accent)
                Text("LEFTOVERS FROM UNINSTALLED APPS")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)
            }
            Spacer()
            if !vm.statusMessage.isEmpty {
                Text(vm.statusMessage.uppercased())
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
            }
            scanButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var scanButton: some View {
        let isBusy = vm.scanState == .buildingMap || vm.scanState == .scanning
        let label: String = {
            switch vm.scanState {
            case .buildingMap: return "BUILDING MAP..."
            case .scanning:    return "SCANNING..."
            default:           return "SCAN"
            }
        }()
        
        return TerminalButton(label, icon: "magnifyingglass") {
            if !isBusy { vm.startScan() }
        }
        .opacity(isBusy ? 0.5 : 1.0)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        switch vm.scanState {
        case .idle:        idlePlaceholder
        case .buildingMap: buildingMapView
        case .scanning:    scanningView
        case .done:
            if vm.rawFiles.isEmpty { emptyView } else { resultsList }
        }
    }

    private var idlePlaceholder: some View {
        VStack(spacing: 12) {
            Text("[ SYSTEM IDLE ]")
                .font(Theme.font(size: 16, weight: .bold))
                .foregroundColor(Theme.textMuted)
            Text("PRESS SCAN TO FIND LEFTOVER FILES\nFROM UNINSTALLED APPS.")
                .multilineTextAlignment(.center)
                .font(Theme.font(size: 12))
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Pass 1 — building occupied-paths map via AppPathFinder
    private var buildingMapView: some View {
        VStack(spacing: 14) {
            Text("[ BUILDING APP MAP... ]")
                .font(Theme.font(size: 16, weight: .bold))
                .foregroundColor(Theme.accent)
            Text(vm.statusMessage.uppercased())
                .font(Theme.font(size: 12))
                .foregroundColor(Theme.textMuted)
                .lineLimit(1)
            // GPU-safe text progress bar (no ProgressView to avoid Metal)
            let filled  = Int(vm.mapProgress * 20)
            let empty   = 20 - filled
            Text("[" + String(repeating: "█", count: max(0, filled))
                     + String(repeating: "░", count: max(0, empty)) + "]")
                .font(Theme.font(size: 14, weight: .bold))
                .foregroundColor(Theme.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Pass 2 — actual reverse scan
    private var scanningView: some View {
        VStack(spacing: 12) {
            Text("[ SCANNING LIBRARY... ]")
                .font(Theme.font(size: 16, weight: .bold))
                .foregroundColor(Theme.accent)
            Text("CROSS-CHECKING AGAINST APP MAP")
                .font(Theme.font(size: 12))
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Text("[ NO ORPHANS FOUND ]")
                .font(Theme.font(size: 16, weight: .bold))
                .foregroundColor(Theme.success)
            Text("LIBRARY IS CLEAN")
                .font(Theme.font(size: 12))
                .foregroundColor(Theme.textMuted)
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
                     ? "\(vm.rawFiles.count) ITEM(S) FOUND"
                     : "\(vm.selectedCount) SELECTED — \(vm.selectedTotalSize)")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textPrimary)
                    .frame(minWidth: 160, alignment: .leading)

                Spacer()

                // Sort buttons
                Text("SORT:")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)
                    .padding(.trailing, 4)

                ForEach(OrphanFinderViewModel.SortOrder.allCases, id: \.self) { order in
                    let isActive = vm.sortOrder == order
                    Text(order.rawValue.uppercased())
                        .font(Theme.font(size: 12, weight: isActive ? .bold : .regular))
                        .foregroundColor(isActive ? Theme.background : Theme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(isActive ? Theme.accent : Color.clear)
                        .border(isActive ? Theme.accent : Color.clear, width: 1)
                        .onTapGesture { vm.sortOrder = order }
                }

                Text("  |  ")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.border)

                // Select/Deselect
                Text("ALL")
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .onTapGesture { vm.selectAll() }

                Text("  ·  ")
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)

                Text("NONE")
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .onTapGesture { vm.deselectAll() }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.surface)

            Rectangle().fill(Theme.border).frame(height: 1)

            // ── List ────────────────────────────────────────────────────
            List(vm.sortedFiles) { file in
                orphanRow(file)
                    .listRowBackground(Theme.background)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private func orphanRow(_ file: OrphanFile) -> some View {
        let isSelected = vm.selectedItems.contains(file.id)
        return HStack(spacing: 8) {
            // Checkbox
            Text(isSelected ? "[X]" : "[ ]")
                .font(Theme.font(size: 14))
                .foregroundColor(isSelected ? Theme.accent : Theme.textMuted)
                .frame(width: 24)
                .onTapGesture { vm.toggleSelection(file.id) }

            // File info
            VStack(alignment: .leading, spacing: 2) {
                Text(file.name)
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text(compactPath(file.path))
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .lineLimit(1)
            }
            .onTapGesture { vm.toggleSelection(file.id) }

            Spacer()

            // Date (shown when sorting by date)
            if vm.sortOrder == .date {
                Text(formattedDate(file.dateModified))
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .frame(width: 70, alignment: .trailing)
            }

            // Size
            Text(file.formattedSize)
                .font(Theme.font(size: 12))
                .foregroundColor(Theme.textMuted)
                .frame(width: 64, alignment: .trailing)

            // Reveal in Finder
            Text("[ FINDER ]")
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(Theme.accent)
                .onTapGesture { vm.revealInFinder(file.url) }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Theme.surface : Color.clear)
        .border(Theme.border, width: 1)
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Text(vm.selectedCount == 0
                 ? "SELECT ITEMS ABOVE TO DELETE"
                 : "\(vm.selectedCount) SELECTED — \(vm.selectedTotalSize)")
                .font(Theme.font(size: 12))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            
            let isDeleting = vm.isDeleting
            let canDelete = vm.selectedCount > 0 && !isDeleting
            
            TerminalButton(isDeleting ? "MOVING TO TRASH..." : "PURGE SELECTED", icon: "trash", isDestructive: true) {
                if canDelete { vm.trashSelected() }
            }
            .opacity(canDelete ? 1.0 : 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.surface)
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
