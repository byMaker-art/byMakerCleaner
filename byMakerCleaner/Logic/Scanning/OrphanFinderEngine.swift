import Foundation
import AppKit

// MARK: - OrphanFile model

/// Represents a single leftover file/folder from an uninstalled application.
struct OrphanFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let matchedBundleID: String
    var dateModified: Date = .distantPast

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var name: String { url.lastPathComponent }
    var path: String { url.path }
}

// MARK: - OrphanScanResult

struct OrphanScanResult {
    var files: [OrphanFile] = []
    var totalSize: Int64 { files.reduce(0) { $0 + $1.size } }
    var formattedTotalSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
}

// MARK: - OrphanFinderEngine

/// Two-pass orphan scanner that mirrors PureMac's accurate "second scan" behaviour.
///
/// ## Algorithm
///
/// ### Pass 1 — Build the "occupied paths" map
/// For every installed application, run `AppPathFinder.findPaths()` (the same
/// 10-level matching engine used by the App Uninstaller). All resulting URLs are
/// collected into a `Set<String>` called `occupiedPaths`.
///
/// ### Pass 2 — Reverse scan
/// Walk each directory in `OrphanSafetyPolicy.allowedRoots` (depth = 1).
/// A candidate entry is an **orphan** only when ALL of the following hold:
///   1. It passes `OrphanSafetyPolicy.isSafeCandidate`.
///   2. Its resolved path is NOT in `occupiedPaths` (i.e. no installed app owns it).
///   3. `NSWorkspace.urlForApplication(withBundleIdentifier:)` also returns nil for
///      any bundle-ID-like name derived from the entry — belt-and-suspenders check.
///   4. The entry is not covered by `skipReverse` or `systemCacheAllowlist`.
///
/// This is identical to what PureMac does on its second "Scan for Orphans" press —
/// the first press uses a fast heuristic that over-reports; the second press runs
/// the full `AppPathFinder` pass which we replicate here from the start, so users
/// always get accurate results on the very first scan.
actor OrphanFinderEngine {

    private let fm = FileManager.default
    private let workspace = NSWorkspace.shared

    // MARK: - System cache allowlist
    // Folder names in ~/Library/Caches and related dirs that belong to
    // Apple OS frameworks, daemons, or deeply embedded system services.
    private static let systemCacheAllowlist: Set<String> = [
        "com.apple", "apple", "geoservices", "cloudkit", "passkit", "gamekit",
        "colorsyncsyncservice", "colorsync", "animoji", "sirikit", "coremedia",
        "coremotion", "coredata", "corelocation", "corebluetooth", "corewlan",
        "coreaudio", "coregraphics", "coreimage", "corespotlight", "corenfc",
        "corehaptics", "coreml", "coretelephony", "coredaemon",
        "networkextension", "network", "nsurlsessiond", "cfnetwork",
        "trustd", "notifyd", "symptomsd", "powerd", "logd", "configd",
        "sandboxd", "sysmond", "mdsync", "mds", "mds_stores",
        "fmflocatord", "findmydeviced",
        "apsd", "aps", "apsd-cache", "pushstore",
        "mediaremoted", "mediasessiond", "avconferenced",
        "accessibility", "assistive", "voiceover",
        "metalperf", "metal", "gpu", "agx",
        "webkit", "webcontentfilter", "webprocess",
        "screensharing", "screencapture", "screentime", "screentimeagent",
        "sirianalytics", "dasd", "duetactivityscheduler",
        "installcoordinationd", "installd", "install",
        "storekit", "storeagent", "commerce", "mas",
        "sharingd", "sharing", "findmy",
        "biome", "biomesyncd",
        "spotlight", "mdworker", "coresearchd",
        "knowledge", "knowledged",
        "privacy", "tcc", "tccd",
        "calendaragent", "reminderkit", "eventkit",
        "coreduet", "contextstoreagent",
        "xprotect", "xprotectupdater", "syspolicyd",
        "aned", "neuralengine",
        "lsd", "lsboxd",
        "shazamkit", "shazam",
        "mobileasset", "assetsd",
        "osanalyticshelper", "diagnosticextensions", "analyticsplatform",
        "feedbacklogger", "feedbackassistant",
        "usernoted", "usbd",
        "followupd", "helpd",
        "contactsd", "addressbook",
        "photosagent", "photosui",
        "mapsd", "maps",
        "newsd", "news",
        "stockswidget",
        "familycircle", "familycircled",
        "transparencyd", "privacyd",
        "voip", "callkit",
        "sms", "imessage", "ids",
        "nsurlcache",
        "cloudd", "cloudpaird", "calaccessd",
        "accountsd", "dataaccessd",
        "cbtoolspath", "ubiquity",
        "secureelement",
        "gpurestartd",
        "syslog", "oslog",
        "crashreporter",
        "installation", "lkdc-setup", "mcxtools",
        "photossearch", "nsattributedstringagent",
        "tmp", "temp", "cache", "caches", "logs", "run", "lock",
        "windowserver", "intervals", "typescript", "pip", "sentrycrash"
    ]

    // MARK: - Public API

    /// Full two-pass scan.
    ///
    /// - Parameter progressHandler: Called on background thread with
    ///   `(appsProcessed, totalApps)` during Pass 1 so the UI can show progress.
    /// - Returns: An `OrphanScanResult` containing only files/folders that
    ///   are definitely NOT owned by any currently installed application.
    func scan(
        progressHandler: (@Sendable (Int, Int) -> Void)? = nil
    ) async -> OrphanScanResult {

        // ── Pass 1: build occupied-paths map ────────────────────────────
        let occupiedPaths = await buildOccupiedPaths(progressHandler: progressHandler)

        // ── Pass 2: reverse scan ─────────────────────────────────────────
        return performReverseScan(occupiedPaths: occupiedPaths)
    }

    // MARK: - Pass 1: Occupied Paths

    /// Runs `AppPathFinder` for every installed app in parallel and merges
    /// all discovered paths into a single `Set<String>` of normalised paths.
    private func buildOccupiedPaths(
        progressHandler: (@Sendable (Int, Int) -> Void)?
    ) async -> Set<String> {

        // Fetch all installed apps (reuses the existing AppInfoFetcher)
        let apps = AppInfoFetcher.shared.fetchInstalledApps()
        let total = apps.count
        var occupiedPaths = Set<String>()

        // Use a TaskGroup so all apps are scanned concurrently.
        // Each child returns a Set<URL> of paths belonging to that app.
        await withTaskGroup(of: (Int, Set<URL>).self) { group in
            for (index, app) in apps.enumerated() {
                let capturedApp = app
                group.addTask {
                    let locations = Locations()
                    // Use .enhanced sensitivity — same as the App Uninstaller.
                    let finder = AppPathFinder(
                        appInfo: capturedApp,
                        locations: locations,
                        sensitivity: .enhanced
                    )
                    let paths = finder.findPaths()
                    return (index + 1, paths)
                }
            }

            for await (processed, paths) in group {
                for url in paths {
                    // Normalise: resolve symlinks so ~/Library and
                    // /private/var/folders/... map to the same key.
                    let resolved = url.resolvingSymlinksInPath().path
                    occupiedPaths.insert(resolved)
                    // Also insert the standardised form as belt-and-suspenders
                    occupiedPaths.insert(url.standardizedFileURL.path)
                }
                progressHandler?(processed, total)
            }
        }

        return occupiedPaths
    }

    // MARK: - Pass 2: Reverse Scan

    /// Walks every path in `OrphanSafetyPolicy.allowedRoots` (depth = 1) and
    /// returns only entries whose path is NOT in `occupiedPaths`.
    private func performReverseScan(occupiedPaths: Set<String>) -> OrphanScanResult {
        var result = OrphanScanResult()

        for rootPath in OrphanSafetyPolicy.allowedRoots {
            let rootURL = URL(fileURLWithPath: rootPath)
            guard fm.fileExists(atPath: rootPath) else { continue }

            guard let enumerator = fm.enumerator(
                at: rootURL,
                includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey,
                                             .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for case let url as URL in enumerator {
                // Only top-level entries (depth = 1)
                let depth = url.pathComponents.count - rootURL.pathComponents.count
                guard depth == 1 else { continue }

                // Safety gate: OrphanSafetyPolicy must approve the candidate
                guard OrphanSafetyPolicy.isSafeCandidate(url) else { continue }

                let resolvedPath = url.resolvingSymlinksInPath().path
                let standardPath = url.standardizedFileURL.path

                // ── Core check: is this path owned by any installed app? ──
                // If YES → skip immediately. This is the key improvement over
                // the old heuristic-only approach (PureMac "second scan" logic).
                if occupiedPaths.contains(resolvedPath) ||
                   occupiedPaths.contains(standardPath) ||
                   occupiedPaths.contains(url.path) {
                    continue
                }

                // ── Also check if any parent in occupiedPaths owns this entry ──
                // e.g. ~/Library/Application Support/MyApp is in occupiedPaths,
                // so ~/Library/Application Support/MyApp/Cache should be skipped.
                if occupiedPaths.contains(where: { resolvedPath.hasPrefix($0 + "/") }) {
                    continue
                }

                let name = url.lastPathComponent
                let nameLower = name.lowercased()

                // ── System allowlist ──────────────────────────────────────
                let key = nameLower.replacingOccurrences(of: " ", with: "")
                if Self.systemCacheAllowlist.contains(key) { continue }
                if Self.systemCacheAllowlist.contains(where: {
                    key.hasPrefix($0) || $0.hasPrefix(key)
                }) { continue }

                // ── skipReverse ───────────────────────────────────────────
                if skipReverse.contains(where: { key.hasPrefix($0) || $0.hasPrefix(key) }) {
                    continue
                }

                // ── Belt-and-suspenders: NSWorkspace bundle ID lookup ─────
                // Even if AppPathFinder missed it, NSWorkspace may know the app.
                if looksLikeBundleID(nameLower) {
                    let baseBID = stripExtension(nameLower)
                    if workspace.urlForApplication(withBundleIdentifier: baseBID) != nil { continue }
                    if let parent = parentBundleID(baseBID),
                       workspace.urlForApplication(withBundleIdentifier: parent) != nil { continue }
                }

                // ── Passed all checks → orphan ────────────────────────────
                if let orphan = makeOrphan(url: url, matchedBundleID: name) {
                    result.files.append(orphan)
                }
            }
        }

        // Default sort: size descending
        result.files.sort { $0.size > $1.size }
        return result
    }

    // MARK: - Helpers

    private func looksLikeBundleID(_ name: String) -> Bool {
        let base = stripExtension(name)
        guard base.contains(".") else { return false }
        let prefixes = ["com.", "org.", "net.", "io.", "co.", "jp.", "de.", "uk.", "fr."]
        return prefixes.contains(where: { base.hasPrefix($0) })
    }

    private func stripExtension(_ name: String) -> String {
        let knownExtensions = [".binarycookies", ".plist", ".log", ".sqlite",
                               ".db", ".cache", ".data", ".lock", ".aapbz"]
        var result = name
        for ext in knownExtensions where result.hasSuffix(ext) {
            result = String(result.dropLast(ext.count))
        }
        return result
    }

    private func parentBundleID(_ bid: String) -> String? {
        let parts = bid.split(separator: ".")
        guard parts.count > 2 else { return nil }
        return parts.dropLast().joined(separator: ".")
    }

    private func makeOrphan(url: URL, matchedBundleID: String) -> OrphanFile? {
        let size = directoryOrFileSize(url)
        guard size >= 0 else { return nil }

        let modDate = (try? url.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate) ?? .distantPast

        return OrphanFile(
            url: url,
            size: size,
            matchedBundleID: matchedBundleID,
            dateModified: modDate
        )
    }

    private func directoryOrFileSize(_ url: URL) -> Int64 {
        guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey]) else {
            return 0
        }
        if values.isDirectory == true {
            var total: Int64 = 0
            if let enumerator = fm.enumerator(
                at: url,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) {
                for case let file as URL in enumerator {
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        total += Int64(size)
                    }
                }
            }
            return total
        } else {
            return Int64(values.fileSize ?? 0)
        }
    }
}
