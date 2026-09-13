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
                    Text(result.category.rawValue)
                        .font(.subheadline).bold()
                    Text("\(result.items.count) item\(result.items.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Toggle all in category
                let allSelected = !result.items.isEmpty && result.items.allSatisfy { $0.isSelected }
                Text(allSelected ? "☑" : "☐")
                    .font(.title3)
                    .foregroundColor(allSelected ? .accentColor : .secondary)
                    .onTapGesture { appState.toggleCategory(result.category) }
                    .padding(.trailing, 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(result.formattedTotalSize)
                        .font(.subheadline).bold()
                        .foregroundColor(result.selectedSize > 0 ? .primary : .secondary)
                    if result.selectedSize > 0 && result.selectedSize != result.totalSize {
                        Text(ByteCountFormatter.string(fromByteCount: result.selectedSize, countStyle: .file) + " selected")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                }

                Text(isExpanded ? "▲" : "▼")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture { isExpanded.toggle() }

            // ── Expanded Items ───────────────────────────────────────
            if isExpanded {
                ForEach(result.items) { item in
                    ItemRowView(item: item, category: result.category)
                    if item.id != result.items.last?.id {
                        Divider().padding(.leading, 44)
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
            Text(item.isSelected ? "☑" : "☐")
                .font(.body)
                .foregroundColor(item.isSelected ? .accentColor : .secondary)
                .onTapGesture { appState.toggleItem(item, inCategory: category) }
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)
                if !item.path.isEmpty {
                    Text(item.path)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                if let date = item.lastModified {
                    Text("Modified: \(date, style: .date)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .onTapGesture { appState.toggleItem(item, inCategory: category) }

            Spacer()

            Text(item.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(item.isSelected ? Color.accentColor.opacity(0.06) : Color.clear)
    }
}
