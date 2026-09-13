import SwiftUI

/// A single category row: shows category name, total size, and expands to show items.
/// Uses Text.onTapGesture throughout — no Button — to avoid Metal crash on Kepler GPU.
struct CategoryRowView: View {
    @EnvironmentObject var appState: AppState
    var result: CategoryResult

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // ── Category Header ──────────────────────────────────────
            HStack(spacing: 10) {
                Text(result.category.emoji)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.category.rawValue.uppercased())
                        .font(Theme.font(size: 14, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                    Text("\(result.items.count) ITEM\(result.items.count == 1 ? "" : "S")")
                        .font(Theme.font(size: 12))
                        .foregroundColor(Theme.textMuted)
                }

                Spacer()

                // Toggle all in category
                let allSelected = !result.items.isEmpty && result.items.allSatisfy { $0.isSelected }
                Text(allSelected ? "[X]" : "[ ]")
                    .font(Theme.font(size: 14))
                    .foregroundColor(allSelected ? Theme.accent : Theme.textMuted)
                    .onTapGesture { appState.toggleCategory(result.category) }
                    .padding(.trailing, 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.formattedTotalSize)
                        .font(Theme.font(size: 14, weight: .bold))
                        .foregroundColor(result.selectedSize > 0 ? Theme.textPrimary : Theme.textMuted)
                    if result.selectedSize > 0 && result.selectedSize != result.totalSize {
                        Text(ByteCountFormatter.string(fromByteCount: result.selectedSize, countStyle: .file) + " SELECTED")
                            .font(Theme.font(size: 10))
                            .foregroundColor(Theme.accent)
                    }
                }

                Text(isExpanded ? "▲" : "▼")
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(isExpanded ? Theme.surface.opacity(0.5) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }

            // ── Expanded Items ───────────────────────────────────────
            if isExpanded {
                ForEach(result.items) { item in
                    ItemRowView(item: item, category: result.category)
                    if item.id != result.items.last?.id {
                        Rectangle().fill(Theme.border).frame(height: 1).padding(.leading, 44)
                    }
                }
            }
        }
    }
}

/// A single cleanable item row.
struct ItemRowView: View {
    @EnvironmentObject var appState: AppState
    let item: CleanableItem
    let category: CleaningCategory

    var body: some View {
        HStack(spacing: 10) {
            // Checkbox
            Text(item.isSelected ? "[X]" : "[ ]")
                .font(Theme.font(size: 14))
                .foregroundColor(item.isSelected ? Theme.accent : Theme.textMuted)
                .onTapGesture { appState.toggleItem(item, inCategory: category) }
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                if !item.path.isEmpty {
                    Text(item.path)
                        .font(Theme.font(size: 10))
                        .foregroundColor(Theme.textMuted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let date = item.lastModified {
                    Text("MODIFIED: \(date, style: .date)")
                        .font(Theme.font(size: 10))
                        .foregroundColor(Theme.textMuted)
                }
            }
            .onTapGesture { appState.toggleItem(item, inCategory: category) }

            Spacer()

            Text(item.formattedSize)
                .font(Theme.font(size: 12))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(item.isSelected ? Theme.surface : Color.clear)
    }
}
