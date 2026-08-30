import Foundation

enum OrphanSafetyPolicy {
    private static let home = FileManager.default.homeDirectoryForCurrentUser.path

    // Conservative allowlist: only volatile data directories.
    // These are the ONLY locations Orphan Finder will ever look in.
    // Any path NOT in this list is automatically ignored — no exceptions.
    static let allowedRoots: [String] = [
        "\(home)/Library/Caches",
        "\(home)/Library/Logs",
        "\(home)/Library/Saved Application State",
        "\(home)/Library/HTTPStorages",
        "\(home)/Library/WebKit",
        "\(home)/Library/Application Support/CrashReporter",
        "/Library/Caches",
        "/Library/Logs",
    ]

    // Absolute blocklist: paths that must NEVER appear in orphan results,
    // even if somehow they end up inside an allowedRoot.
    // Keychains, launch agents, mail data, system security — untouchable.
    private static let blockedFragments: [String] = [
        // User data that must never be touched
        "/Library/Preferences",
        "/Library/PreferencePanes",
        "/Library/Containers",
        "/Library/Group Containers",
        "/Library/Application Scripts",
        "/Library/LaunchAgents",
        "/Library/LaunchDaemons",
        "/Library/PrivilegedHelperTools",
        "/Library/Keychains",
        "/Library/Mail",
        "/Library/Safari",
        "/Library/Messages",
        "/Library/Calendars",
        "/Library/Accounts",
        "/Library/Mobile Documents",
        "/Library/CloudStorage",
        // Security & authentication
        "/Library/Security",
        "/Library/Biometric",
        // System extension points
        "/Library/SystemExtensions",
        "/Library/Extensions",
        "/Library/Kernel",
    ]

    // Name-based blocklist: filenames or folder names that are
    // unconditionally safe to skip regardless of location.
    // Catches system-owned items whose names don't start with com.apple.
    static let safeNameBlocklist: Set<String> = [
        // Apple cluster filesystems & networking
        "xsan",
        "xsan-debug",
        "afp",
        "smb",
        // Firewall & network security
        "hidfw-crashlogs",
        "lkdc-setup",
        "alf",           // Application Layer Firewall
        "socketfilterfw",
        // OCLP / OpenCore (critical on patched systems)
        "dortania",
        "opencore",
        "oclp",
        "opencore-legacy-patcher",
        "ocvalidate",
        // Apple diagnostic & crash infrastructure
        "diagnosticd",
        "diagnosticextensions",
        "osanalytics",
        "osanalyticshelper",
        "sysdiagnose",
        "spindump",
        "oomanalyticsd",
        "wifivelalog",
        "coreduetd",
        "duetactivityscheduler",
        // Kext & driver infrastructure
        "kextd",
        "kexts",
        "kextcache",
        "sysextd",
        // Cryptography & secure enclave
        "sealed",
        "crypto",
        "corecrypto",
        "systempolicy",
        "syspolicyd",
        "authd",
        // Time Machine & APFS internals
        "timemachine",
        "backupd",
        "coreservicesd",
        "apfs",
        "diskarbitrationd",
        // Boot, firmware & recovery
        "recovery",
        "recoveryos",
        "bootp",
        "bless",
        "nvram",
        "smc",
        // System Integrity & SIP
        "sip",
        "amfid",
        "csr",
        // Package & installer infrastructure
        "installer",
        "installcoordinationd",
        "pkgutil",
        "receipts",
        "bom",
        // Developer tools that may be actively in use
        "lldb",
        "dtrace",
        "instruments-trace",
        "xcrun",
        "simctl",
        // Generic system cache names that should never be orphans
        "powerlog",
        "powerd",
        "powerdatad",
        "batteryd",
        "knowledged",
        "knowledge",
        "analyticsd",
        "analyticsplatform",
        "swiftlang",
    ]

    static func isSafeCandidate(_ url: URL) -> Bool {
        let path = normalizedPath(url)
        let lowerPath = path.lowercased()
        let name = url.lastPathComponent.lowercased()

        // ── Level 1: High-risk home dotpaths (SSH keys, credentials, etc.) ──
        // Defined in Conditions.swift — belt-and-suspenders for CLI configs.
        for root in highRiskHomeDotPaths {
            if path == root || path.hasPrefix(root + "/") { return false }
        }

        // ── Level 2: Require path to be strictly inside an allowedRoot ──
        // This is the primary boundary: only Caches, Logs, HTTPStorages,
        // WebKit, Saved Application State, and CrashReporter are in scope.
        guard allowedRoots.contains(where: { root in
            let rootWithSlash = root.lowercased() + "/"
            return lowerPath.hasPrefix(rootWithSlash)
        }) else { return false }

        // ── Level 3: blockedFragments — absolute path blacklist ───────────
        // Even inside allowedRoots, certain sub-paths are off limits.
        if blockedFragments.contains(where: { lowerPath.contains($0.lowercased()) }) {
            return false
        }

        // ── Level 4: Apple-owned items by prefix ─────────────────────────
        if name.hasPrefix("com.apple.") || name == ".globalpreferences.plist" {
            return false
        }

        // ── Level 5: Name-based blocklist ─────────────────────────────────
        // System infrastructure items that are never orphans regardless of
        // their bundle-ID-style name.
        let key = name
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "_", with: "")
        if safeNameBlocklist.contains(key) { return false }
        if safeNameBlocklist.contains(where: { key.hasPrefix($0) }) { return false }

        // ── Level 6: Symlink guard ──────────────────────────────────────
        // Never follow or flag symlinks — prevents traversal attacks.
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let type = attrs[.type] as? FileAttributeType,
           type == .typeSymbolicLink {
            return false
        }

        return true
    }

    private static func normalizedPath(_ url: URL) -> String {
        url.standardizedFileURL.resolvingSymlinksInPath().path
    }
}
