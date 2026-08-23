import Foundation

// MARK: - CleaningCategory

enum CleaningCategory: String, CaseIterable, Identifiable {
    case systemJunk      = "System Junk"
    case userCache       = "User Cache"
    case trashBins       = "Trash Bins"
    case aiApps          = "AI Apps"
    case mailAttachments = "Mail Attachments"
    case xcodeJunk       = "Xcode Junk"
    case brewCache       = "Homebrew Cache"
    case nodeCache       = "Node Cache"
    case dockerCache     = "Docker Cache"
    case largeFiles      = "Large & Old Files"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .systemJunk:      return "🗂️"
        case .userCache:       return "📦"
        case .trashBins:       return "🗑️"
        case .aiApps:          return "🤖"
        case .mailAttachments: return "📎"
        case .xcodeJunk:       return "🔨"
        case .brewCache:       return "🍺"
        case .nodeCache:       return "📗"
        case .dockerCache:     return "🐳"
        case .largeFiles:      return "📁"
        }
    }

    var description: String {
        switch self {
        case .systemJunk:
            return "System caches, logs and temp files"
        case .userCache:
            return "Application caches in ~/Library/Caches"
        case .trashBins:
            return "Items in Trash on all volumes"
        case .aiApps:
            return "Logs and caches from Ollama, LM Studio"
        case .mailAttachments:
            return "Downloaded mail attachments"
        case .xcodeJunk:
            return "DerivedData, Archives, Simulator caches"
        case .brewCache:
            return "Homebrew download cache"
        case .nodeCache:
            return "npm, yarn, pnpm caches"
        case .dockerCache:
            return "Docker build cache and logs"
        case .largeFiles:
            return "Files >100 MB or older than 1 year (not selected by default)"
        }
    }

    /// Whether items in this category are safe to auto-select
    var isAutoSelected: Bool {
        switch self {
        case .largeFiles: return false
        default: return true
        }
    }
}

// MARK: - CleanableItem

struct CleanableItem: Identifiable {
    let id = UUID()
    let name: String
    let path: String
    let size: Int64
    let category: CleaningCategory
    var isSelected: Bool
    let lastModified: Date?

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - CategoryResult

struct CategoryResult: Identifiable {
    let id = UUID()
    let category: CleaningCategory
    var items: [CleanableItem]
    let totalSize: Int64

    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }

    var selectedItems: [CleanableItem] {
        items.filter { $0.isSelected }
    }

    var selectedSize: Int64 {
        selectedItems.reduce(0) { $0 + $1.size }
    }
}

// MARK: - ScanState

enum ScanState: Equatable {
    case idle
    case scanning(currentPath: String)
    case done
    case cleaning
    case cleanDone(freedBytes: Int64)
}
