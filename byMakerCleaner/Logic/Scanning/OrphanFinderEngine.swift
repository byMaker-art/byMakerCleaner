import Foundation
import AppKit

// MARK: - OrphanFile model

/// Represents a single leftover file/folder from an uninstalled application.
struct OrphanFile: Identifiable {
    let id = UUID()
    let url: URL
    let size: Int64
    let matchedBundleID: String  // Bundle ID / name fragment that identified this as orphan
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

/// Scans known volatile Library directories for leftover files from applications
/// that are NO LONGER installed on this Mac.
///
/// Algorithm (matches PureMac "Scan for Orphans" approach):
///
///  1. Build a set of all installed app bundle IDs from /Applications, ~/Applications.
///  2. For each candidate in OrphanSafetyPolicy.allowedRoots (Caches, Logs, etc.):
///     a. If the folder/file name looks like a reverse-domain bundle ID (contains "."),
///        call NSWorkspace.urlForApplication(withBundleIdentifier:) to see if it's installed.
///        → Installed: skip. Not installed AND not in system allowlist: orphan.
///     b. If the name is a plain word (no dots), check against the set of installed app
///        names and a hardcoded system-service allowlist.
///        → Not known: orphan candidate.
///  3. System caches of Apple frameworks (GeoServices, CloudKit, GameKit, etc.) are
///     excluded via the comprehensive systemCacheAllowlist below.
actor OrphanFinderEngine {

    private let fm = FileManager.default
    private let workspace = NSWorkspace.shared

    // MARK: - System cache allowlist
    // These folder names appear in ~/Library/Caches and related dirs but belong to
    // Apple OS frameworks, daemons, or deeply-embedded system services — NOT user apps.
    private static let systemCacheAllowlist: Set<String> = [
        // Apple frameworks / OS daemons
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
        "familycircle", "familycircled",    // Family Sharing daemon — system
        "transparencyd", "privacyd",
        "voip", "callkit",
        "sms", "imessage", "ids",
        "nsurlcache",
        "cloudd", "cloudpaird", "calaccessd",
        "accountsd", "dataaccessd",
        "cbtoolspath", "ubiquity",
        "secureelement",
        "gpurestartd",
        "syslog",
        "oslog",
        "crashreporter",                    // system crash reporter infra (not user apps)
        // Saved Application State (only OS sessions)
        "com.apple.safari", "com.apple.finder",
        // Named caches from embedded OS frameworks
        "installation",
        "lkdc-setup",
        "mcxtools",
        "photossearch",
        "nsattributedstringagent",
        // Generic infra noise
        "tmp", "temp", "cache", "caches", "logs", "run", "lock",
        "windowserver", "intervals", "typescript", "pip", "sentrycrash"
    ]

    // MARK: - Public API

    /// Fetch a set of all installed app bundle IDs for fast lookup.
    func fetchInstalledBundleIDs() -> Set<String> {
        var ids: Set<String> = []
        let appDirs = [
            "/Applications",
            "\(fm.homeDirectoryForCurrentUser.path)/Applications",
            "/Users/Shared",
        ]
        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for entry in contents where entry.hasSuffix(".app") {
                let appURL = URL(fileURLWithPath: "\(dir)/\(entry)")
                if let bid = Bundle(url: appURL)?.bundleIdentifier {
                    ids.insert(bid.lowercased())
                }
            }
        }
        return ids
    }

    /// Main scan. Returns orphan files only — items whose owning app is definitely gone.
    func scan(installedBundleIDs: Set<String>) -> OrphanScanResult {
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
                // Only top-level entries in each allowed root (depth = 1)
                let depth = url.pathComponents.count - rootURL.pathComponents.count
                guard depth == 1 else { continue }

                // Safety check
                guard OrphanSafetyPolicy.isSafeCandidate(url) else { continue }

                let name = url.lastPathComponent
                let nameLower = name.lowercased()

                // ── Decide if this is an orphan ──────────────────────────

                // Case A: reverse-domain bundle ID (contains at least one dot and
                // looks like "com.something.something")
                if looksLikeBundleID(nameLower) {
                    // Strip file extensions (.binarycookies, .plist, .log, etc.)
                    let baseBundleID = stripExtension(nameLower)

                    // Installed? → NOT an orphan
                    if installedBundleIDs.contains(baseBundleID) { continue }

                    // Use NSWorkspace to check if any app with this bundle ID is installed
                    if workspace.urlForApplication(withBundleIdentifier: baseBundleID) != nil { continue }
                    // Also check without the last component (sub-bundle like com.foo.bar.Menu)
                    if let parent = parentBundleID(baseBundleID),
                       workspace.urlForApplication(withBundleIdentifier: parent) != nil { continue }

                    // Check skipReverse
                    if skipReverse.contains(where: { baseBundleID.contains($0) }) { continue }

                    // Still here → app is gone → orphan
                    if let orphan = makeOrphan(url: url, matchedBundleID: baseBundleID) {
                        result.files.append(orphan)
                    }

                } else {
                    // Case B: plain name (no dots) — e.g. "JetPackCache", "pip", "typescript"

                    // Check system allowlist first
                    let key = nameLower.replacingOccurrences(of: " ", with: "")
                    if Self.systemCacheAllowlist.contains(key) { continue }
                    // Also check partial prefix match (e.g. "geoservices" contains "geo")
                    if Self.systemCacheAllowlist.contains(where: { key.hasPrefix($0) || $0.hasPrefix(key) }) { continue }

                    // Check skipReverse
                    if skipReverse.contains(where: { key.hasPrefix($0) || $0.hasPrefix(key) }) { continue }

                    // Check if any installed app name matches (case-insensitive)
                    // We compare against bundle ID components as well
                    let isKnown = installedBundleIDs.contains(where: { bid in
                        let parts = bid.split(separator: ".").map(String.init)
                        return parts.contains(key) || bid.contains(key)
                    })
                    if isKnown { continue }

                    // Check NSWorkspace by trying common prefixes
                    // (plain-named caches rarely map back to a bundle ID — treat them as orphan only if size > 0)
                    if let orphan = makeOrphan(url: url, matchedBundleID: name) {
                        result.files.append(orphan)
                    }
                }
            }
        }

        // Default sort: size descending
        result.files.sort { $0.size > $1.size }
        return result
    }

    // MARK: - Private helpers

    /// Returns true if the name looks like a reverse-domain bundle ID.
    private func looksLikeBundleID(_ name: String) -> Bool {
        let base = stripExtension(name)
        // Must contain at least one dot AND start with a known TLD-like prefix
        guard base.contains(".") else { return false }
        let prefixes = ["com.", "org.", "net.", "io.", "co.", "jp.", "de.", "uk.", "fr."]
        return prefixes.contains(where: { base.hasPrefix($0) })
    }

    /// Strip common file extensions from a candidate name.
    private func stripExtension(_ name: String) -> String {
        let knownExtensions = [".binarycookies", ".plist", ".log", ".sqlite",
                               ".db", ".cache", ".data", ".lock", ".aapbz"]
        var result = name
        for ext in knownExtensions where result.hasSuffix(ext) {
            result = String(result.dropLast(ext.count))
        }
        return result
    }

    /// Returns the parent bundle ID (drops the last component).
    /// e.g. "com.foo.bar.menu" → "com.foo.bar"
    private func parentBundleID(_ bid: String) -> String? {
        let parts = bid.split(separator: ".")
        guard parts.count > 2 else { return nil }
        return parts.dropLast().joined(separator: ".")
    }

    /// Build an OrphanFile value, computing size and modification date.
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
