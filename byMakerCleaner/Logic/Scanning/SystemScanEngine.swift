import Foundation

/// System junk scanner — ported and adapted from PureMac (MIT license).
/// Scans categories of system/user junk without touching any files.
/// All scanning is read-only; deletion is handled by SystemCleaningEngine.
actor SystemScanEngine {

    private let fileManager = FileManager.default
    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    // Throttled path reporter for the scanning status ticker
    private var onPath: (@Sendable (String) -> Void)?
    private var lastReport = Date.distantPast

    private func report(_ path: @autoclosure () -> String) {
        guard let onPath else { return }
        let now = Date()
        guard now.timeIntervalSince(lastReport) > 0.1 else { return }
        lastReport = now
        onPath(path())
    }

    // MARK: - Public API

    /// Scan a single category and return results.
    func scanCategory(
        _ category: CleaningCategory,
        onPath: (@Sendable (String) -> Void)? = nil
    ) async -> CategoryResult {
        self.onPath = onPath
        defer { self.onPath = nil }

        switch category {
        case .systemJunk:      return scanSystemJunk()
        case .userCache:       return scanUserCache()
        case .trashBins:       return scanTrash()
        case .aiApps:          return scanAIApps()
        case .mailAttachments: return scanMailAttachments()
        case .xcodeJunk:       return scanXcodeJunk()
        case .brewCache:       return scanBrewCache()
        case .nodeCache:       return scanNodeCache()
        case .dockerCache:     return scanDockerCache()
        case .largeFiles:      return scanLargeFiles()
        }
    }

    // MARK: - Category Scanners

    private func scanSystemJunk() -> CategoryResult {
        let paths = [
            "/Library/Logs",
            "/private/var/log",
            "\(home)/Library/Logs",
            "/tmp",
            "/private/var/tmp",
        ]
        var items: [CleanableItem] = []
        for path in paths {
            items.append(contentsOf: scanDirectory(path: path, category: .systemJunk, maxDepth: 3))
        }
        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .systemJunk, items: items, totalSize: totalSize)
    }

    private func scanUserCache() -> CategoryResult {
        var items: [CleanableItem] = []

        // Exclude paths owned by other categories + cloud providers
        let excludedRootPaths = Set((
            [
                "\(home)/Library/Caches/Homebrew",
                "\(home)/Library/Caches/com.electron.ollama",
                "\(home)/Library/Caches/ollama",
            ] + ProviderPaths.deniedRoots
        ).map { normalizePath($0) })

        let scanned = scanDirectory(
            path: "\(home)/Library/Caches",
            category: .userCache,
            maxDepth: 1,
            excluding: excludedRootPaths
        )
        items.append(contentsOf: scanned)

        // Sandboxed app container caches
        let containerRoots = [
            "\(home)/Library/Containers",
            "\(home)/Library/Group Containers",
        ]
        for root in containerRoots {
            guard let containers = try? fileManager.contentsOfDirectory(atPath: root) else { continue }
            let cacheSubpath = root.hasSuffix("Group Containers")
                ? "Library/Caches"
                : "Data/Library/Caches"
            for container in containers {
                let cachePath = (root as NSString)
                    .appendingPathComponent(container)
                    .appending("/" + cacheSubpath)
                let resolved = URL(fileURLWithPath: cachePath).resolvingSymlinksInPath().path
                guard normalizePath(resolved) == normalizePath(cachePath) else { continue }
                if let item = makeItem(name: "\(container) (sandbox cache)",
                                       path: cachePath,
                                       category: .userCache,
                                       minimumSize: 1024 * 1024) {
                    items.append(item)
                }
            }
        }

        let unique = deduplicated(items)
        let totalSize = unique.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .userCache, items: unique, totalSize: totalSize)
    }

    private func scanTrash() -> CategoryResult {
        var items: [CleanableItem] = []

        // 1) Main user trash — minimumSize:0 so even tiny files (aliases, .DS_Store)
        // are shown; Finder counts them and shows the Trash as non-empty.
        items.append(contentsOf: scanDirectory(
            path: "\(home)/.Trash",
            category: .trashBins,
            maxDepth: 1,
            minimumSize: 0
        ))

        // 2) Trash on every mounted volume (e.g. external drives, APFS containers)
        // Each volume has a .Trashes/<uid>/ folder that Finder also shows.
        let uid = getuid()
        let volumeURLs = fileManager.mountedVolumeURLs(
            includingResourceValuesForKeys: [.volumeIsLocalKey],
            options: [.skipHiddenVolumes]
        ) ?? []

        for volumeURL in volumeURLs {
            // Skip the root volume — already covered by ~/.Trash above
            if volumeURL.path == "/" { continue }
            // Only local (non-network) volumes
            if let values = try? volumeURL.resourceValues(forKeys: [.volumeIsLocalKey]),
               values.volumeIsLocal == false { continue }

            let trashPath = volumeURL.appendingPathComponent(".Trashes/\(uid)").path
            items.append(contentsOf: scanDirectory(
                path: trashPath,
                category: .trashBins,
                maxDepth: 1,
                minimumSize: 0
            ))
        }

        let unique = deduplicated(items)
        let totalSize = unique.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .trashBins, items: unique, totalSize: totalSize)
    }


    private func scanAIApps() -> CategoryResult {
        struct Target { let name: String; let path: String; let selected: Bool }
        let targets: [Target] = [
            Target(name: "Ollama Logs",            path: "\(home)/.ollama/logs",                                             selected: true),
            Target(name: "Ollama Cache",           path: "\(home)/Library/Caches/ollama",                                   selected: true),
            Target(name: "Ollama Electron Cache",  path: "\(home)/Library/Caches/com.electron.ollama",                      selected: true),
            Target(name: "Ollama WebKit Data",     path: "\(home)/Library/WebKit/com.electron.ollama",                      selected: true),
            Target(name: "Ollama Saved State",     path: "\(home)/Library/Saved Application State/com.electron.ollama.savedState", selected: true),
            Target(name: "Ollama CLI History (optional)", path: "\(home)/.ollama/history",                                  selected: false),
            Target(name: "LM Studio Server Logs",  path: "\(home)/.lmstudio/server-logs",                                   selected: true),
            Target(name: "LM Studio Conversations (optional)", path: "\(home)/.lmstudio/conversations",                     selected: false),
        ]
        let items = deduplicated(targets.compactMap {
            makeItem(name: $0.name, path: $0.path, category: .aiApps, isSelected: $0.selected, minimumSize: 0)
        })
        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .aiApps, items: items.sorted { $0.size > $1.size }, totalSize: totalSize)
    }

    private func scanMailAttachments() -> CategoryResult {
        let paths = [
            "\(home)/Library/Mail Downloads",
            "\(home)/Library/Containers/com.apple.mail/Data/Library/Mail Downloads",
        ]
        var items: [CleanableItem] = []
        for path in paths {
            items.append(contentsOf: scanDirectory(path: path, category: .mailAttachments, maxDepth: 3))
        }
        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .mailAttachments, items: items, totalSize: totalSize)
    }

    private func scanXcodeJunk() -> CategoryResult {
        let paths = [
            "\(home)/Library/Developer/Xcode/DerivedData",
            "\(home)/Library/Developer/Xcode/Archives",
            "\(home)/Library/Developer/CoreSimulator/Caches",
            "\(home)/Library/Caches/com.apple.dt.Xcode",
            "\(home)/Library/Developer/Xcode/iOS DeviceSupport",
            "\(home)/Library/Developer/Xcode/watchOS DeviceSupport",
            "\(home)/Library/Developer/Xcode/tvOS DeviceSupport",
            "\(home)/Library/Developer/XCTestDevices",
            "\(home)/Library/Developer/Xcode/UserData/Previews",
            "\(home)/Library/Caches/org.swift.swiftpm",
            "\(home)/Library/org.swift.swiftpm",
        ]
        var items: [CleanableItem] = []
        for path in paths {
            guard fileManager.fileExists(atPath: path) else { continue }
            let size = directorySize(path: path)
            guard size > 0 else { continue }
            items.append(CleanableItem(
                name: URL(fileURLWithPath: path).lastPathComponent,
                path: path,
                size: size,
                category: .xcodeJunk,
                isSelected: true,
                lastModified: nil
            ))
        }
        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .xcodeJunk, items: items, totalSize: totalSize)
    }

    private func scanBrewCache() -> CategoryResult {
        var brewPaths = ["\(home)/Library/Caches/Homebrew"]

        // Try to detect custom HOMEBREW_CACHE via `brew --cache`
        let knownBrewRoots = [
            "\(home)/Library/Caches/Homebrew",
            "/opt/homebrew/Library/Caches",
            "/usr/local/Homebrew/Library/Caches",
        ]
        for brewBin in ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"] {
            guard fileManager.fileExists(atPath: brewBin) else { continue }
            if let detected = runCommand(executable: brewBin, args: ["--cache"]) {
                let trimmed = detected.trimmingCharacters(in: .whitespacesAndNewlines)
                let normalized = normalizePath(trimmed)
                let isKnown = knownBrewRoots.contains { normalized == $0 || normalized.hasPrefix($0 + "/") }
                if isKnown, !brewPaths.map(normalizePath).contains(normalized) {
                    brewPaths.append(trimmed)
                }
            }
            break
        }

        var items: [CleanableItem] = []
        for path in brewPaths {
            if let item = makeItem(name: URL(fileURLWithPath: path).lastPathComponent, path: path, category: .brewCache) {
                items.append(item)
            }
        }
        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .brewCache, items: items, totalSize: totalSize)
    }

    private func scanNodeCache() -> CategoryResult {
        struct Manager { let name: String; let defaultPath: String; let cli: String?; let cliArgs: [String] }
        let managers: [Manager] = [
            Manager(name: "npm cache",                    defaultPath: "\(home)/.npm",                      cli: "npm",  cliArgs: ["config", "get", "cache"]),
            Manager(name: "yarn classic cache",           defaultPath: "\(home)/Library/Caches/Yarn",       cli: "yarn", cliArgs: ["cache", "dir"]),
            Manager(name: "pnpm content-addressable store", defaultPath: "\(home)/Library/pnpm/store",     cli: "pnpm", cliArgs: ["store", "path"]),
        ]
        let cliSearchPaths = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "\(home)/.volta/bin"]

        var items: [CleanableItem] = []
        for manager in managers {
            var paths = [manager.defaultPath]
            if let cli = manager.cli,
               let cliPath = locateExecutable(named: cli, in: cliSearchPaths),
               let detected = runCommand(executable: cliPath, args: manager.cliArgs) {
                let trimmed = detected.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty, !paths.map(normalizePath).contains(normalizePath(trimmed)) {
                    paths.append(trimmed)
                }
            }
            for path in paths {
                if let item = makeItem(name: manager.name, path: path, category: .nodeCache) {
                    items.append(item)
                }
            }
        }
        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .nodeCache, items: items, totalSize: totalSize)
    }

    private func scanDockerCache() -> CategoryResult {
        let paths = [
            "\(home)/Library/Containers/com.docker.docker/Data/cache",
            "\(home)/Library/Containers/com.docker.docker/Data/log",
            "\(home)/Library/Containers/com.docker.docker/Data/tmp",
            "\(home)/Library/Group Containers/group.com.docker/Caches",
            "\(home)/.docker/buildx/cache",
            "\(home)/.orbstack/log",
            "\(home)/Library/Logs/OrbStack",
        ]
        var items: [CleanableItem] = []
        for path in paths {
            if let item = makeItem(name: URL(fileURLWithPath: path).lastPathComponent, path: path, category: .dockerCache) {
                items.append(item)
            }
        }
        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .dockerCache, items: items, totalSize: totalSize)
    }

    private func scanLargeFiles() -> CategoryResult {
        var items: [CleanableItem] = []
        let minSize: Int64 = 100 * 1024 * 1024 // 100 MB
        let oldCutoff = Calendar.current.date(byAdding: .month, value: -12, to: Date()) ?? Date.distantPast

        let searchPaths = [
            "\(home)/Downloads",
            "\(home)/Documents",
            "\(home)/Desktop",
        ]

        for basePath in searchPaths {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: basePath),
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
                options: [.skipsPackageDescendants, .skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if Task.isCancelled { break }
                report(fileURL.path)
                guard let rv = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                      rv.isRegularFile == true,
                      let fileSize = rv.fileSize else { continue }
                let size = Int64(fileSize)
                let modDate = rv.contentModificationDate
                let isOld = modDate != nil && modDate! < oldCutoff && size > 10 * 1024 * 1024
                if size > minSize || isOld {
                    items.append(CleanableItem(
                        name: fileURL.lastPathComponent,
                        path: fileURL.path,
                        size: size,
                        category: .largeFiles,
                        isSelected: false,
                        lastModified: modDate
                    ))
                }
            }
        }
        items.sort { $0.size > $1.size }
        let totalSize = items.reduce(0) { $0 + $1.size }
        return CategoryResult(category: .largeFiles, items: items, totalSize: totalSize)
    }

    // MARK: - Helpers

    private func scanDirectory(
        path: String,
        category: CleaningCategory,
        maxDepth: Int,
        isSelected: Bool = true,
        minimumSize: Int64 = 1024,
        excluding excludedPaths: Set<String> = []
    ) -> [CleanableItem] {
        var items: [CleanableItem] = []

        guard fileManager.fileExists(atPath: path),
              fileManager.isReadableFile(atPath: path) else { return [] }

        do {
            let contents = try fileManager.contentsOfDirectory(atPath: path)
            for name in contents {
                if Task.isCancelled { break }
                let fullPath = (path as NSString).appendingPathComponent(name)
                report(fullPath)

                if excludedPaths.contains(normalizePath(fullPath)) { continue }

                // Skip symlinks (security)
                if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                   let fileType = attrs[.type] as? FileAttributeType,
                   fileType == .typeSymbolicLink { continue }

                // Skip SIP-protected entries
                if FileProtection.isProtectedFromDeletion(path: fullPath) { continue }

                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }

                if isDir.boolValue {
                    let size = directorySize(path: fullPath)
                    if size > minimumSize {
                        items.append(CleanableItem(
                            name: name,
                            path: fullPath,
                            size: size,
                            category: category,
                            isSelected: isSelected,
                            lastModified: fileModDate(path: fullPath)
                        ))
                    }
                } else {
                    if let attrs = try? fileManager.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? Int64, size >= minimumSize {
                        items.append(CleanableItem(
                            name: name,
                            path: fullPath,
                            size: size,
                            category: category,
                            isSelected: isSelected,
                            lastModified: attrs[.modificationDate] as? Date
                        ))
                    }
                }
            }
        } catch {
            Logger.shared.log("Cannot enumerate \(path): \(error.localizedDescription)", level: .warning)
        }
        return items
    }

    private func makeItem(
        name: String,
        path: String,
        category: CleaningCategory,
        isSelected: Bool = true,
        minimumSize: Int64 = 1024
    ) -> CleanableItem? {
        report(path)
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory),
              fileManager.isReadableFile(atPath: path) else { return nil }

        if isDirectory.boolValue {
            let size = directorySize(path: path)
            guard size > minimumSize else { return nil }
            return CleanableItem(name: name, path: path, size: size, category: category,
                                 isSelected: isSelected, lastModified: fileModDate(path: path))
        }

        guard let attrs = try? fileManager.attributesOfItem(atPath: path),
              let size = attrs[.size] as? Int64, size > minimumSize else { return nil }
        return CleanableItem(name: name, path: path, size: size, category: category,
                             isSelected: isSelected, lastModified: attrs[.modificationDate] as? Date)
    }

    private func directorySize(path: String) -> Int64 {
        var total: Int64 = 0
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        for case let fileURL as URL in enumerator {
            if Task.isCancelled { break }
            guard let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            if let size = values.totalFileAllocatedSize ?? values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }

    private func fileModDate(path: String) -> Date? {
        try? fileManager.attributesOfItem(atPath: path)[.modificationDate] as? Date
    }

    private func normalizePath(_ path: String) -> String {
        (path as NSString).standardizingPath
    }

    private func deduplicated(_ items: [CleanableItem]) -> [CleanableItem] {
        var seen = Set<String>()
        return items.filter { seen.insert(normalizePath($0.path)).inserted }
    }

    // MARK: - Process helpers

    private func locateExecutable(named name: String, in searchPaths: [String]) -> String? {
        for dir in searchPaths {
            let candidate = (dir as NSString).appendingPathComponent(name)
            if fileManager.isExecutableFile(atPath: candidate) { return candidate }
        }
        return nil
    }

    private func runCommand(executable: String, args: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }
        guard task.terminationStatus == 0 else { return nil }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
