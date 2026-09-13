//
//  Conditions.swift
//  byMakerCleaner
//
//  Per-app matching rules and system-level skip conditions for the heuristic scan engine.
//  These define edge cases where bundle ID and app name matching alone is insufficient.
//

import Foundation

// MARK: - AppCondition

/// Defines per-app overrides for the heuristic file matcher.
///
/// Some apps use naming conventions that collide with other apps (e.g. "Xcode" vs "Xcodes"),
/// or scatter files under unexpected names. This struct lets the scanner include additional
/// search terms, exclude false positives, and force-include/exclude specific filesystem paths.
struct AppCondition: Codable {
    let bundleID: String
    let includeTerms: [String]
    let excludeTerms: [String]
    let forceIncludePaths: [URL]?
    let forceExcludePaths: [URL]?

    init(
        bundleID: String,
        includeTerms: [String],
        excludeTerms: [String],
        forceIncludePaths: [String]? = nil,
        forceExcludePaths: [String]? = nil
    ) {
        self.bundleID = bundleID.normalizedForMatching()
        self.includeTerms = includeTerms.map { $0.normalizedForMatching() }
        self.excludeTerms = excludeTerms.map { $0.normalizedForMatching() }
        self.forceIncludePaths = forceIncludePaths?.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        self.forceExcludePaths = forceExcludePaths?.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }
}

// MARK: - SkipCondition

/// Defines prefixes and paths that should be skipped during scanning.
///
/// `skipPrefixes` - Normalized filename prefixes that are always skipped (e.g. system plists).
/// `allowPrefixes` - Exceptions to skipPrefixes for Apple apps we DO want to scan.
/// `skipPaths` - Absolute paths that should never appear in scan results.
struct SkipCondition {
    let skipPrefixes: [String]
    let allowPrefixes: [String]
    let skipPaths: [String]
}

// MARK: - App Conditions Database

/// Per-app matching overrides.
/// Each entry handles a specific app whose files cannot be reliably found by bundle ID alone.
let appConditions: [AppCondition] = [

    // ---------------------------------------------------------------
    // Homebrew Cask-sourced exact paths (community verified)
    // ---------------------------------------------------------------
    AppCondition(
        bundleID: "org.mozilla.firefox",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "/Library/Logs/DiagnosticReports/firefox_*",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/org.mozilla.firefox.sfl*",
            "\(home)/Library/Application Support/CrashReporter/firefox_*",
            "\(home)/Library/Application Support/Firefox",
            "\(home)/Library/Caches/Firefox",
            "\(home)/Library/Caches/Mozilla/updates/Applications/Firefox",
            "\(home)/Library/Caches/org.mozilla.crashreporter",
            "\(home)/Library/Caches/org.mozilla.firefox",
            "\(home)/Library/Preferences/org.mozilla.crashreporter.plist",
            "\(home)/Library/Preferences/org.mozilla.firefox.plist",
            "\(home)/Library/Saved Application State/org.mozilla.firefox.savedState",
            "\(home)/Library/WebKit/org.mozilla.firefox"
        ]
    ),
    AppCondition(
        bundleID: "md.obsidian",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/md.obsidian.sfl*",
            "\(home)/Library/Application Support/obsidian",
            "\(home)/Library/Preferences/md.obsidian.plist",
            "\(home)/Library/Saved Application State/md.obsidian.savedState"
        ]
    ),
    AppCondition(
        bundleID: "ru.keepcoder.Telegram",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/*.ru.keepcoder.Telegram",
            "\(home)/Library/Application Scripts/*.ru.keepcoder.Telegram.TelegramShare",
            "\(home)/Library/Application Scripts/ru.keepcoder.Telegram",
            "\(home)/Library/Application Scripts/ru.keepcoder.Telegram.TelegramShare",
            "\(home)/Library/Application Support/ru.keepcoder.Telegram",
            "\(home)/Library/Caches/com.plausiblelabs.crashreporter.data/ru.keepcoder.Telegram",
            "\(home)/Library/Caches/ru.keepcoder.Telegram",
            "\(home)/Library/Containers/ru.keepcoder.Telegram",
            "\(home)/Library/Containers/ru.keepcoder.Telegram.TelegramShare",
            "\(home)/Library/Cookies/ru.keepcoder.Telegram.binarycookies",
            "\(home)/Library/Group Containers/*.ru.keepcoder.Telegram",
            "\(home)/Library/Group Containers/*.ru.keepcoder.Telegram.TelegramShare",
            "\(home)/Library/HTTPStorages/ru.keepcoder.Telegram",
            "\(home)/Library/Preferences/ru.keepcoder.Telegram.plist",
            "\(home)/Library/Saved Application State/ru.keepcoder.Telegram.savedState"
        ]
    ),
    AppCondition(
        bundleID: "com.valvesoftware.steam",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Steam",
            "\(home)/Library/LaunchAgents/com.valvesoftware.steamclean.plist",
            "\(home)/Library/Preferences/com.valvesoftware.steam.helper.plist",
            "\(home)/Library/Saved Application State/com.valvesoftware.steam.savedState"
        ]
    ),
    AppCondition(
        bundleID: "org.videolan.vlc",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/org.videolan.vlc.sfl*",
            "\(home)/Library/Application Support/org.videolan.vlc",
            "\(home)/Library/Application Support/VLC",
            "\(home)/Library/Caches/org.videolan.vlc",
            "\(home)/Library/HTTPStorages/org.videolan.vlc",
            "\(home)/Library/Preferences/org.videolan.vlc",
            "\(home)/Library/Preferences/org.videolan.vlc.plist",
            "\(home)/Library/Saved Application State/org.videolan.vlc.savedState"
        ]
    ),
    AppCondition(
        bundleID: "com.tinyspeck.slackmacgap",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "/Library/Logs/DiagnosticReports/Slack_*",
            "\(home)/Library/Application Scripts/com.tinyspeck.slackmacgap",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.tinyspeck.slackmacgap.sfl*",
            "\(home)/Library/Application Support/Slack",
            "\(home)/Library/Caches/com.tinyspeck.slackmacgap*",
            "\(home)/Library/Containers/com.tinyspeck.slackmacgap*",
            "\(home)/Library/Cookies/com.tinyspeck.slackmacgap.binarycookies",
            "\(home)/Library/Group Containers/*.com.tinyspeck.slackmacgap",
            "\(home)/Library/Group Containers/*.slack",
            "\(home)/Library/HTTPStorages/com.tinyspeck.slackmacgap*",
            "\(home)/Library/Logs/Slack",
            "\(home)/Library/Preferences/ByHost/com.tinyspeck.slackmacgap.ShipIt.*.plist",
            "\(home)/Library/Preferences/com.tinyspeck.slackmacgap*",
            "\(home)/Library/Saved Application State/com.tinyspeck.slackmacgap.savedState",
            "\(home)/Library/WebKit/com.tinyspeck.slackmacgap"
        ]
    ),
    AppCondition(
        bundleID: "com.hnc.Discord",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.hnc.discord.sfl*",
            "\(home)/Library/Application Support/discord",
            "\(home)/Library/Application%20Support/discord",
            "\(home)/Library/Caches/com.hnc.Discord",
            "\(home)/Library/Caches/com.hnc.Discord.ShipIt",
            "\(home)/Library/Cookies/com.hnc.Discord.binarycookies",
            "\(home)/Library/HTTPStorages/com.hnc.Discord",
            "\(home)/Library/HTTPStorages/com.hnc.Discord.binarycookies",
            "\(home)/Library/Preferences/ByHost/com.discord.discord.ShipIt.*.plist",
            "\(home)/Library/Preferences/com.hnc.Discord.helper.plist",
            "\(home)/Library/Preferences/com.hnc.Discord.plist",
            "\(home)/Library/Saved Application State/com.hnc.Discord.savedState"
        ]
    ),
    AppCondition(
        bundleID: "com.microsoft.VSCode",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Code",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.microsoft.vscode.sfl*",
            "\(home)/Library/Caches/com.microsoft.VSCode",
            "\(home)/Library/Caches/com.microsoft.VSCode.ShipIt",
            "\(home)/Library/HTTPStorages/com.microsoft.VSCode",
            "\(home)/Library/Preferences/ByHost/com.microsoft.VSCode.ShipIt.*.plist",
            "\(home)/Library/Preferences/com.microsoft.VSCode.helper.plist",
            "\(home)/Library/Preferences/com.microsoft.VSCode.plist",
            "\(home)/Library/Saved Application State/com.microsoft.VSCode.savedState"
        ]
    ),
    AppCondition(
        bundleID: "us.zoom.xos",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/*.ZoomClient3rd",
            "\(home)/Library/Application Support/CloudDocs/session/containers/iCloud.us.zoom.videomeetings",
            "\(home)/Library/Application Support/CloudDocs/session/containers/iCloud.us.zoom.videomeetings.plist",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/us.zoom*.sfl*",
            "\(home)/Library/Application Support/CrashReporter/zoom.us*",
            "\(home)/Library/Application Support/zoom.us",
            "\(home)/Library/Application Support/ZoomUpdater",
            "\(home)/Library/Caches/us.zoom.xos",
            "\(home)/Library/Cookies/us.zoom.xos.binarycookies",
            "\(home)/Library/Group Containers/*.ZoomClient3rd",
            "\(home)/Library/HTTPStorages/us.zoom.xos",
            "\(home)/Library/HTTPStorages/us.zoom.xos.binarycookies",
            "\(home)/Library/Internet Plug-Ins/ZoomUsPlugIn.plugin",
            "\(home)/Library/Logs/zoom.us",
            "\(home)/Library/Logs/zoominstall.log",
            "\(home)/Library/Logs/ZoomPhone",
            "\(home)/Library/Preferences/us.zoom.*.plist",
            "\(home)/Library/Preferences/ZoomChat.plist",
            "\(home)/Library/Saved Application State/us.zoom.xos.savedState",
            "\(home)/Library/WebKit/us.zoom.xos"
        ]
    ),
    AppCondition(
        bundleID: "com.spotify.client",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.spotify.client.startuphelper.sfl*",
            "\(home)/Library/Application Support/Spotify",
            "\(home)/Library/Caches/com.spotify.client",
            "\(home)/Library/Caches/com.spotify.client.helper",
            "\(home)/Library/Cookies/com.spotify.client.binarycookies",
            "\(home)/Library/HTTPStorages/com.spotify.client",
            "\(home)/Library/HTTPStorages/com.spotify.client.helper",
            "\(home)/Library/Logs/Spotify",
            "\(home)/Library/Preferences/com.spotify.client.helper.plist",
            "\(home)/Library/Preferences/com.spotify.client.plist",
            "\(home)/Library/Saved Application State/com.spotify.client.savedState",
            "\(home)/Library/WebKit/com.spotify.client"
        ]
    ),
    AppCondition(
        bundleID: "com.colliderli.iina",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/com.colliderli.iina.OpenInIINA",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.colliderli.iina.sfl*",
            "\(home)/Library/Application Support/com.colliderli.iina",
            "\(home)/Library/Application Support/CrashReporter/IINA*.plist",
            "\(home)/Library/Caches/com.colliderli.iina",
            "\(home)/Library/Containers/com.colliderli.iina.OpenInIINA",
            "\(home)/Library/Cookies/com.colliderli.iina.binarycookies",
            "\(home)/Library/HTTPStorages/com.colliderli.iina",
            "\(home)/Library/Logs/com.colliderli.iina",
            "\(home)/Library/Logs/DiagnosticReports/IINA*.crash",
            "\(home)/Library/Preferences/com.colliderli.iina.plist",
            "\(home)/Library/Safari/Extensions/Open in IINA*.safariextz",
            "\(home)/Library/Saved Application State/com.colliderli.iina.savedState",
            "\(home)/Library/WebKit/com.colliderli.iina"
        ]
    ),
    AppCondition(
        bundleID: "org.m0k.transmission",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/org.m0k.transmission.sfl*",
            "\(home)/Library/Application Support/Transmission",
            "\(home)/Library/Caches/com.apple.helpd/SDMHelpData/Other/English/HelpSDMIndexFile/org.m0k.transmission.help",
            "\(home)/Library/Caches/com.apple.helpd/SDMHelpData/Other/English/HelpSDMIndexFile/Transmission Help*",
            "\(home)/Library/Caches/org.m0k.transmission",
            "\(home)/Library/Cookies/org.m0k.transmission.binarycookies",
            "\(home)/Library/Preferences/org.m0k.transmission.LSSharedFileList.plist",
            "\(home)/Library/Preferences/org.m0k.transmission.plist",
            "\(home)/Library/Saved Application State/org.m0k.transmission.savedState"
        ]
    ),
    AppCondition(
        bundleID: "cx.c3.theunarchiver",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Caches/cx.c3.theunarchiver",
            "\(home)/Library/Cookies/cx.c3.theunarchiver.binarycookies",
            "\(home)/Library/Preferences/cx.c3.theunarchiver.plist",
            "\(home)/Library/Saved Application State/cx.c3.theunarchiver.savedState"
        ]
    ),
    AppCondition(
        bundleID: "com.aone.keka",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/*.group.com.aone.keka",
            "\(home)/Library/Application Scripts/com.aone.keka",
            "\(home)/Library/Application Scripts/com.aone.keka.KekaFinderIntegration",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.aone.keka.sfl*",
            "\(home)/Library/Application Support/Keka",
            "\(home)/Library/Caches/com.aone.keka",
            "\(home)/Library/Containers/com.aone.keka",
            "\(home)/Library/Containers/com.aone.keka.KekaFinderIntegration",
            "\(home)/Library/Group Containers/*.group.com.aone.keka",
            "\(home)/Library/Preferences/com.aone.keka.plist",
            "\(home)/Library/Saved Application State/com.aone.keka.savedState"
        ]
    ),
    AppCondition(
        bundleID: "com.googlecode.iterm2",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/com.googlecode.iterm2.iTermFileProvider",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.googlecode.iterm2.itermai.sfl*",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.googlecode.iterm2.sfl*",
            "\(home)/Library/Application Support/iTerm",
            "\(home)/Library/Application Support/iTerm2",
            "\(home)/Library/Caches/com.googlecode.iterm2",
            "\(home)/Library/Containers/com.googlecode.iterm2.iTermFileProvider",
            "\(home)/Library/Containers/iTermAI",
            "\(home)/Library/Cookies/com.googlecode.iterm2.binarycookies",
            "\(home)/Library/HTTPStorages/com.googlecode.iterm2",
            "\(home)/Library/HTTPStorages/com.googlecode.iterm2.binarycookies",
            "\(home)/Library/Preferences/com.googlecode.iterm2.plist",
            "\(home)/Library/Preferences/com.googlecode.iterm2.private.plist",
            "\(home)/Library/Saved Application State/com.googlecode.iterm2*.savedState",
            "\(home)/Library/WebKit/com.googlecode.iterm2"
        ]
    ),
    AppCondition(
        bundleID: "com.raycast.macos",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/com.raycast.macos.BrowserExtension",
            "\(home)/Library/Application Support/com.raycast.macos",
            "\(home)/Library/Caches/com.raycast.macos",
            "\(home)/Library/Caches/SentryCrash/Raycast",
            "\(home)/Library/Containers/com.raycast.macos.BrowserExtension",
            "\(home)/Library/Cookies/com.raycast.macos.binarycookies",
            "\(home)/Library/HTTPStorages/com.raycast.macos",
            "\(home)/Library/Preferences/com.raycast.macos.plist",
            "\(home)/Library/WebKit/com.raycast.macos"
        ]
    ),
    AppCondition(
        bundleID: "com.knollsoft.Rectangle",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/com.knollsoft.RectangleLauncher",
            "\(home)/Library/Application Support/Rectangle",
            "\(home)/Library/Caches/com.knollsoft.Rectangle",
            "\(home)/Library/Containers/com.knollsoft.RectangleLauncher",
            "\(home)/Library/HTTPStorages/com.knollsoft.Rectangle",
            "\(home)/Library/Preferences/com.knollsoft.Rectangle.plist",
            "\(home)/Library/WebKit/com.knollsoft.Rectangle"
        ]
    ),
    AppCondition(
        bundleID: "notion.id",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Caches/notion-updater",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/notion.id.sfl*",
            "\(home)/Library/Application Support/Notion",
            "\(home)/Library/Caches/notion.id*",
            "\(home)/Library/Logs/Notion",
            "\(home)/Library/Preferences/ByHost/notion.id.*",
            "\(home)/Library/Preferences/notion.id.*",
            "\(home)/Library/Saved Application State/notion.id.savedState",
            "\(home)/Library/WebKit/notion.id"
        ]
    ),
    AppCondition(
        bundleID: "com.bitwarden.desktop",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Bitwarden",
            "\(home)/Library/Caches/com.bitwarden.desktop",
            "\(home)/Library/Caches/com.bitwarden.desktop.ShipIt",
            "\(home)/Library/Logs/Bitwarden",
            "\(home)/Library/Preferences/ByHost/com.bitwarden.desktop.ShipIt.*.plist",
            "\(home)/Library/Preferences/com.bitwarden.desktop.helper.plist",
            "\(home)/Library/Preferences/com.bitwarden.desktop.plist",
            "\(home)/Library/Saved Application State/com.bitwarden.desktop.savedState"
        ]
    ),
    AppCondition(
        bundleID: "com.1password.1password",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/2BUA8C4S2C.com.1password*",
            "\(home)/Library/Application Scripts/2BUA8C4S2C.com.agilebits",
            "\(home)/Library/Application Scripts/com.1password.1password-launcher",
            "\(home)/Library/Application Scripts/com.1password.browser-support",
            "\(home)/Library/Application Support/1Password",
            "\(home)/Library/Application Support/Arc/User Data/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.1password.1password.sfl*",
            "\(home)/Library/Application Support/CrashReporter/1Password*",
            "\(home)/Library/Application Support/Google/Chrome Beta/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/Google/Chrome Canary/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/Google/Chrome Dev/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/Microsoft Edge Beta/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/Microsoft Edge Canary/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/Microsoft Edge Dev/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/Microsoft Edge/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/Mozilla/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Application Support/Vivaldi/NativeMessagingHosts/com.1password.1password.json",
            "\(home)/Library/Containers/2BUA8C4S2C.com.1password.browser-helper",
            "\(home)/Library/Containers/com.1password.1password*",
            "\(home)/Library/Containers/com.1password.browser-support",
            "\(home)/Library/Group Containers/2BUA8C4S2C.com.1password",
            "\(home)/Library/Group Containers/2BUA8C4S2C.com.agilebits",
            "\(home)/Library/Logs/1Password",
            "\(home)/Library/Preferences/com.1password.1password.plist",
            "\(home)/Library/Preferences/group.com.1password.plist",
            "\(home)/Library/Saved Application State/com.1password.1password.savedState"
        ]
    ),
    AppCondition(
        bundleID: "com.brave.Browser",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/BraveSoftware/Brave-Browser",
            "\(home)/Library/Caches/BraveSoftware/Brave-Browser",
            "\(home)/Library/Caches/com.brave.Browser",
            "\(home)/Library/HTTPStorages/com.brave.Browser",
            "\(home)/Library/Preferences/com.brave.Browser.plist",
            "\(home)/Library/Saved Application State/com.brave.Browser.savedState"
        ]
    ),
    AppCondition(
        bundleID: "net.whatsapp.WhatsApp",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/group.net.whatsapp.family",
            "\(home)/Library/Application Scripts/group.net.whatsapp.WhatsApp.private",
            "\(home)/Library/Application Scripts/group.net.whatsapp.WhatsApp.shared",
            "\(home)/Library/Application Scripts/group.net.whatsapp.WhatsAppSMB.shared",
            "\(home)/Library/Application Scripts/net.whatsapp.WhatsApp*",
            "\(home)/Library/Caches/net.whatsapp.WhatsApp",
            "\(home)/Library/Containers/net.whatsapp.WhatsApp*",
            "\(home)/Library/Group Containers/group.com.facebook.family",
            "\(home)/Library/Group Containers/group.net.whatsapp*",
            "\(home)/Library/Saved Application State/net.whatsapp.WhatsApp.savedState"
        ]
    ),
    AppCondition(
        bundleID: "org.whispersystems.signal-desktop",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Signal",
            "\(home)/Library/Preferences/org.whispersystems.signal-desktop.helper.plist",
            "\(home)/Library/Preferences/org.whispersystems.signal-desktop.plist",
            "\(home)/Library/Saved Application State/org.whispersystems.signal-desktop.savedState"
        ]
    ),
    AppCondition(
        bundleID: "com.microsoft.edgemac",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Scripts/com.microsoft.edgemac.wdgExtension",
            "\(home)/Library/Application Support/Microsoft Edge",
            "\(home)/Library/Application Support/Microsoft/EdgeUpdater",
            "\(home)/Library/Caches/com.microsoft.edgemac",
            "\(home)/Library/Caches/com.microsoft.EdgeUpdater",
            "\(home)/Library/Caches/Microsoft Edge",
            "\(home)/Library/Containers/com.microsoft.edgemac.wdgExtension",
            "\(home)/Library/HTTPStorages/com.microsoft.edgemac",
            "\(home)/Library/HTTPStorages/com.microsoft.EdgeUpdater",
            "\(home)/Library/LaunchAgents/com.microsoft.EdgeUpdater.*.plist",
            "\(home)/Library/Microsoft/MicrosoftSoftwareUpdate/Actives/com.microsoft.edgemac",
            "\(home)/Library/Preferences/com.microsoft.edgemac.plist",
            "\(home)/Library/Saved Application State/com.microsoft.edgemac.savedState",
            "\(home)/Library/WebKit/com.microsoft.edgemac"
        ]
    ),
    AppCondition(
        bundleID: "com.figma.Desktop",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.figma.desktop.sfl*",
            "\(home)/Library/Application Support/Figma",
            "\(home)/Library/Application Support/figma-desktop",
            "\(home)/Library/Caches/com.figma.agent",
            "\(home)/Library/Caches/com.figma.Desktop",
            "\(home)/Library/HTTPStorages/com.figma.agent",
            "\(home)/Library/Preferences/com.figma.Desktop.plist",
            "\(home)/Library/Saved Application State/com.figma.Desktop.savedState"
        ]
    ),
    AppCondition(
        bundleID: "ch.sudo.cyberduck",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Cyberduck",
            "\(home)/Library/Caches/ch.sudo.cyberduck",
            "\(home)/Library/Group Containers/G69SCX94XU.duck",
            "\(home)/Library/HTTPStorages/ch.sudo.cyberduck",
            "\(home)/Library/Logs/Cyberduck",
            "\(home)/Library/Preferences/ch.sudo.cyberduck.plist",
            "\(home)/Library/Saved Application State/ch.sudo.cyberduck.savedState"
        ]
    ),
    AppCondition(
        bundleID: "com.tinyapp.TablePlus",
        includeTerms: [],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.tinyapp.tableplus.sfl*",
            "\(home)/Library/Application Support/com.tinyapp.TablePlus",
            "\(home)/Library/Caches/com.tinyapp.TablePlus",
            "\(home)/Library/Cookies/com.tinyapp.TablePlus.binarycookies",
            "\(home)/Library/HTTPStorages/com.tinyapp.TablePlus",
            "\(home)/Library/Preferences/com.tinyapp.TablePlus.plist",
            "\(home)/Library/Saved Application State/com.tinyapp.TablePlus.savedState"
        ]
    ),

    // ---------------------------------------------------------------
    // Apple Developer Tools
    // ---------------------------------------------------------------

    // Xcode: includes simulator containers, DerivedData markers, and Apple DT prefixes.
    // Must exclude Xcodes.app (third-party Xcode version manager) and Xcode cleaner utilities.
    AppCondition(
        bundleID: "com.apple.dt.xcode",
        includeTerms: ["com.apple.dt", "xcode", "simulator"],
        excludeTerms: [
            "com.robotsandpencils.xcodesapp",
            "com.xcodesorg.xcodesapp",
            "com.oneminutegames.xcodecleaner",
            "io.hyperapp.xcodecleaner",
            "available-xcodes",
            "xcodes",
            "cleaner for xcode"
        ],
        forceIncludePaths: [
            "\(home)/Library/Containers/com.apple.iphonesimulator.ShareExtension"
        ]
    ),

    // Developer.app — Apple WWDC app (developer.apple.wwdc-Release).
    // SAFETY: The app name is "Developer" which naively matches ~/Library/Developer
    // and /Library/Developer (Xcode DerivedData, Simulators, toolchains — 30+ GB!).
    // This condition locks the search to the bundle ID prefix only and explicitly
    // blocks the 'developer' name-token so it can never capture system directories.
    AppCondition(
        bundleID: "developer.apple.wwdc-release",
        includeTerms: ["developer.apple.wwdc"],  // only match the explicit bundle ID prefix
        excludeTerms: ["developer", "library", "xcode", "simulator"]  // block all generic tokens
    ),

    // Xcodes.app (robotsandpencils variant)
    AppCondition(
        bundleID: "com.robotsandpencils.xcodesapp",
        includeTerms: [],
        excludeTerms: [
            "com.apple.dt.xcode",
            "com.oneminutegames.xcodecleaner",
            "io.hyperapp.xcodecleaner"
        ]
    ),

    // Xcodes.app (xcodesorg variant)
    AppCondition(
        bundleID: "com.xcodesorg.xcodesapp",
        includeTerms: [],
        excludeTerms: [
            "com.apple.dt.xcode",
            "com.oneminutegames.xcodecleaner",
            "io.hyperapp.xcodecleaner"
        ]
    ),

    // Xcode Cleaner (hyperapp)
    AppCondition(
        bundleID: "io.hyperapp.xcodecleaner",
        includeTerms: [],
        excludeTerms: [
            "com.robotsandpencils.xcodesapp",
            "com.oneminutegames.xcodecleaner",
            "com.apple.dt.xcode",
            "xcodes.json"
        ]
    ),

    // ---------------------------------------------------------------
    // Communication & Video Conferencing
    // ---------------------------------------------------------------

    // Zoom: uses "us.zoom.xos" bundle but files are often named just "zoom".
    AppCondition(
        bundleID: "us.zoom.xos",
        includeTerms: ["zoom"],
        excludeTerms: []
    ),

    // Microsoft Teams: exclude general Office shared frameworks.
    AppCondition(
        bundleID: "com.microsoft.teams2",
        includeTerms: [],
        excludeTerms: ["office"]
    ),

    // ---------------------------------------------------------------
    // Web Browsers
    // ---------------------------------------------------------------

    // Brave Browser
    AppCondition(
        bundleID: "com.brave.browser",
        includeTerms: ["brave"],
        excludeTerms: []
    ),

    // Google Chrome: include "google" and "chrome" but exclude iTerm's chromefeaturestate
    // and unrelated "monochrome" matches.
    AppCondition(
        bundleID: "com.google.chrome",
        includeTerms: ["google", "chrome"],
        excludeTerms: ["iterm", "chromefeaturestate", "monochrome"]
    ),

    // Microsoft Edge: exclude other Microsoft products that share the "com.microsoft" prefix.
    AppCondition(
        bundleID: "com.microsoft.edgemac",
        includeTerms: [],
        excludeTerms: ["vscode", "rdc", "appcenter", "office", "oneauth"]
    ),

    // Mozilla Firefox (release)
    AppCondition(
        bundleID: "org.mozilla.firefox",
        includeTerms: ["firefox"],
        excludeTerms: ["thunderbird"]
    ),

    // Mozilla Firefox Nightly
    AppCondition(
        bundleID: "org.mozilla.firefox.nightly",
        includeTerms: ["mozilla", "firefox"],
        excludeTerms: ["thunderbird"]
    ),

    // Mozilla Thunderbird
    AppCondition(
        bundleID: "org.mozilla.thunderbird",
        includeTerms: [],
        excludeTerms: ["firefox"]
    ),

    // Arc Browser: uses Firestore for sync; force-include its App Support and Caches folders.
    AppCondition(
        bundleID: "company.thebrowser.Browser",
        includeTerms: ["firestore"],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Arc/",
            "\(home)/Library/Caches/Arc/"
        ]
    ),

    // ---------------------------------------------------------------
    // Developer Tools & IDEs
    // ---------------------------------------------------------------

    // VS Code: force-include the "Code" support directory.
    // Must exclude VS Code Insiders to prevent cross-contamination.
    AppCondition(
        bundleID: "com.microsoft.VSCode",
        includeTerms: ["vscode"],
        excludeTerms: ["vscodeinsiders", "insiders"],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Code/"
        ]
    ),

    // VS Code Insiders: separate from stable VS Code.
    AppCondition(
        bundleID: "com.microsoft.VSCodeInsiders",
        includeTerms: ["vscodeinsiders", "insiders"],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Code - Insiders/"
        ]
    ),

    // GitHub Desktop: uses "comgithubelectron" in some legacy cache paths.
    AppCondition(
        bundleID: "com.github.githubclient",
        includeTerms: ["comgithubelectron"],
        excludeTerms: []
    ),

    // JetBrains IDEs (IntelliJ, PyCharm, WebStorm, etc.): share common directories.
    // The bundle ID prefix "jetbrains" matches all JetBrains products.
    AppCondition(
        bundleID: "jetbrains",
        includeTerms: ["jcef"],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/JetBrains/",
            "\(home)/Library/Caches/JetBrains/",
            "\(home)/Library/Logs/JetBrains/"
        ]
    ),

    // Native Instruments (Native Access, Kontakt, etc.)
    AppCondition(
        bundleID: "com.native-instruments.nativeaccess",
        includeTerms: ["comnative", "nativeinstruments"],
        excludeTerms: []
    ),

    // ---------------------------------------------------------------
    // Productivity & Utilities
    // ---------------------------------------------------------------

    // Logi Options+: "logi" prefix collides with "login" and "logic".
    AppCondition(
        bundleID: "com.logi.optionsplus",
        includeTerms: ["logi", "logipluginservice"],
        excludeTerms: ["login", "logic"]
    ),

    // 1Password: uses shared Chromium-based browser engine paths.
    AppCondition(
        bundleID: "com.1password.1password",
        includeTerms: ["waveboxapp", "sidekick"],
        excludeTerms: []
    ),

    // Stats (system monitor): exclude "video" to avoid matching video-stats plists.
    AppCondition(
        bundleID: "eu.exelban.stats",
        includeTerms: [],
        excludeTerms: ["video"]
    ),

    // BatteryToolkit: plist prefix uses concatenated form "memhaeuser".
    AppCondition(
        bundleID: "me.mhaeuser.BatteryToolkit",
        includeTerms: ["memhaeuser"],
        excludeTerms: []
    ),

    // Okta Verify
    AppCondition(
        bundleID: "com.okta.mobile",
        includeTerms: ["okta"],
        excludeTerms: []
    ),

    // ---------------------------------------------------------------
    // Virtualization & Remote Access
    // ---------------------------------------------------------------

    // BlueStacks: uses interprocess communication files with non-obvious names.
    AppCondition(
        bundleID: "com.now.gg.BlueStacks",
        includeTerms: ["bst_boost_interprocess"],
        excludeTerms: []
    ),

    // StrongDM: Electron app with "sdm" bundle but files named "strongdm".
    AppCondition(
        bundleID: "com.electron.sdm",
        includeTerms: ["strongdm"],
        excludeTerms: []
    ),

    // ---------------------------------------------------------------
    // Social & Messaging
    // ---------------------------------------------------------------

    // Facebook Archon (Workplace): includes login helper with different naming.
    AppCondition(
        bundleID: "com.facebook.archon.developerid",
        includeTerms: ["archon.loginhelper"],
        excludeTerms: []
    ),

    // ---------------------------------------------------------------
    // Games & Launchers
    // ---------------------------------------------------------------

    // Steam: stores ~1+ GB of game data under "Steam" (not the bundle ID).
    // ~/Library/Application Support/Steam contains steamapps, config, userdata.
    // ~/Library/Caches/Steam contains shader caches.
    // Without forceIncludePaths the heuristic finds the .app (11 MB) only,
    // because "steam" ≠ "comvalvesoftwaresteam" in normalized form at depth-2.
    AppCondition(
        bundleID: "com.valvesoftware.steam",
        includeTerms: ["steam", "valvesoftware"],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Steam",
            "\(home)/Library/Caches/Steam",
            "\(home)/Library/LaunchAgents/com.valvesoftware.steamclean.plist"
        ]
    ),

    // Epic Games Launcher: stores game library in a non-obvious location.
    AppCondition(
        bundleID: "com.epicgames.launcher",
        includeTerms: ["epicgames", "epic"],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Epic Games",
            "\(home)/Library/Application Support/com.epicgames.launcher",
            "\(home)/Library/Caches/com.epicgames.launcher"
        ]
    ),

    // Battle.net (Blizzard): stores game data outside standard paths.
    AppCondition(
        bundleID: "net.battle.app",
        includeTerms: ["battlenet", "blizzard"],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Battle.net",
            "\(home)/Library/Caches/com.blizzard.battle.net"
        ]
    ),

    // ---------------------------------------------------------------
    // Browsers — additional profile data
    // ---------------------------------------------------------------

    // Spotify: stores large audio cache in Application Support/Spotify
    AppCondition(
        bundleID: "com.spotify.client",
        includeTerms: ["spotify"],
        excludeTerms: [],
        forceIncludePaths: [
            "\(home)/Library/Application Support/Spotify",
            "\(home)/Library/Caches/com.spotify.client"
        ]
    ),

    // ---------------------------------------------------------------
    // Apps with name collision — require isolation from each other
    // ---------------------------------------------------------------

    // Antigravity (com.google.antigravity): must NOT capture files of Antigravity IDE.
    // "antigravity" as a search token matches both apps' file names.
    // excludeTerms blocks the IDE-specific bundle suffixes from being counted.
    AppCondition(
        bundleID: "com.google.antigravity",
        includeTerms: ["com.google.antigravity"],
        excludeTerms: ["antigravity-ide", "antigravityide", "antigravity ide"]
    ),

    // Antigravity IDE (com.google.antigravity-ide): must NOT capture base Antigravity files.
    AppCondition(
        bundleID: "com.google.antigravity-ide",
        includeTerms: ["com.google.antigravity-ide", "antigravity-ide", "antigravityide"],
        excludeTerms: []
    ),

    // CLIP STUDIO (jp.co.celsys.CLIPSTUDIO): must NOT capture CLIP STUDIO PAINT files.
    // Both apps share "clip studio" in their name, causing cross-contamination.
    AppCondition(
        bundleID: "jp.co.celsys.clipstudio",
        includeTerms: ["jp.co.celsys.clipstudio"],
        excludeTerms: ["clipstudiopaint", "clip studio paint", "celsys.clipstudiopaint"]
    ),

    // CLIP STUDIO PAINT (jp.co.celsys.CLIPSTUDIOPAINT): must NOT capture CLIP STUDIO files.
    AppCondition(
        bundleID: "jp.co.celsys.clipstudiopaint",
        includeTerms: ["jp.co.celsys.clipstudiopaint", "clipstudiopaint"],
        excludeTerms: ["jp.co.celsys.clipstudio"]
    ),

    // ---------------------------------------------------------------
    // System Components — must never be offered for deletion
    // ---------------------------------------------------------------

    // OpenCore-Patcher (com.dortania.opencore-legacy-patcher):
    // This is a CRITICAL OCLP system component. Its files in ~/Library/Logs/Dortania
    // are already protected by OrphanSafetyPolicy, but we add an explicit
    // forceExcludePaths guard here so the Uninstaller also never inflates its size
    // by capturing system-level OCLP artifacts.
    AppCondition(
        bundleID: "com.dortania.opencore-legacy-patcher",
        includeTerms: ["com.dortania.opencore-legacy-patcher", "opencore-legacy-patcher"],
        excludeTerms: ["dortania", "opencore", "oclp"]  // block loose tokens — too dangerous
    ),

]

// MARK: - Skip Conditions

/// System-level skip rules applied globally during scanning.
/// Prevents the scanner from matching macOS system files, the Trash, and known false positives.
let skipConditions: [SkipCondition] = [
    SkipCondition(
        skipPrefixes: [
            "mobiledocuments",
            "reminders",
            "dsstore",
            "comapplepasswordmanager"
        ],
        allowPrefixes: [
            "comappleconfigurator",
            "comappledt",
            "comappleiwork",
            "comapplesfsymbols",
            "comappletestflight",
            "comapplesharedfilelist",
            "comapplelssharedfilelist"
        ],
        skipPaths: [
            "\(home)/.Trash",
            // Developer directories: contains Xcode DerivedData, iOS Simulators,
            // Instruments, toolchains. These are Xcode's data, NOT files belonging
            // to any third-party app. Including them would inflate sizes by 30+ GB
            // and risk destroying developer environments.
            // Developer.app (Apple WWDC) must NEVER capture these paths.
            "\(home)/Library/Developer",
            "/Library/Developer",
            // System extension infrastructure
            "/Library/SystemExtensions",
            "/System/Volumes/Preboot/Cryptexes/App/System/Library/CoreServices/PasswordManagerBrowserExtensionHelper.app/Contents/MacOS/PasswordManagerBrowserExtensionHelper",
            "\(home)/Library/Application Support/Chromium/NativeMessagingHosts/com.apple.passwordmanager.json",
            "\(home)/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.apple.passwordmanager.json"
        ] + highRiskHomeDotPaths
    )
]

/// Home-directory dotdirs that must never be matched as app artifacts no
/// matter how short or coincidental the app name is. Adding an entry here is
/// the correct fix for "removing webapp X also deleted my CLI tool X config"
/// (see issues #50 / #51).
let highRiskHomeDotPaths: [String] = [
    "\(home)/.claude",
    "\(home)/.ssh",
    "\(home)/.aws",
    "\(home)/.gnupg",
    "\(home)/.gpg",
    "\(home)/.kube",
    "\(home)/.docker",
    "\(home)/.config",
    "\(home)/.git",
    "\(home)/.gitconfig",
    "\(home)/.git-credentials",
    "\(home)/.netrc",
    "\(home)/.npmrc",
    "\(home)/.yarnrc",
    "\(home)/.pnpmrc",
    "\(home)/.pip",
    "\(home)/.pypirc",
    "\(home)/.rbenv",
    "\(home)/.pyenv",
    "\(home)/.nvm",
    "\(home)/.cargo",
    "\(home)/.rustup",
    "\(home)/.gem",
    "\(home)/.local",
    "\(home)/.password-store",
    "\(home)/.mozilla",
    "\(home)/.wine",
    "\(home)/.vscode",
    "\(home)/.vim",
    "\(home)/.viminfo",
    "\(home)/.zshrc",
    "\(home)/.zsh_history",
    "\(home)/.bash_history",
    "\(home)/.bashrc",
    "\(home)/.bash_profile",
    "\(home)/.profile",
]

// MARK: - Deep Search Exclusions

/// Library subdirectories excluded from depth=2 (deep) search.
/// These are macOS system directories that never contain third-party app files.
/// Searching them wastes time and produces false positives.
let skipDeepSearch: Set<String> = [

    // Core System
    "Apple", "Audio", "Bluetooth", "ColorSync", "Components", "CoreAnalytics",
    "CoreMediaIO", "DirectoryServices", "Filesystems", "GPUBundles", "Graphics",
    "KernelCollections", "OSAnalytics", "OpenDirectory", "Sandbox", "Security",
    "SystemExtensions", "SystemMigration", "SystemProfiler", "StagedDriverExtensions",
    "StagedExtensions", "StartupItems",

    // User Data & System Services
    "Accessibility", "Accounts", "AppleMediaServices", "Assistant", "Assistants",
    "Autosave Information", "Biome", "Calendars", "CallServices", "CloudStorage",
    "Contacts", "Cookies", "DataAccess", "DataDeliveryServices", "DoNotDisturb",
    "DuetExpertCenter", "Finance", "FinanceBackup", "FrontBoard", "GameKit",
    "GroupContainersAlias", "HomeKit", "IdentityServices", "IntelligencePlatform",
    "Intents", "KeyboardServices", "LanguageModeling", "LockdownMode", "Mail",
    "MediaAnalysis", "Messages", "Metadata", "Mobile Documents", "MobileDevice",
    "News", "Passes", "PersonalizationPortrait", "Photos", "PrivateCloudCompute",
    "Reminders", "ResponseKit", "Safari", "SafariSafeBrowsing", "SafariSandboxBroker",
    "ScreenRecordings", "StatusKit", "Suggestions", "SyncedPreferences", "Translation",
    "UnifiedAssetFramework", "Weather", "homeenergyd", "studentd",

    // Development & System Tools
    "Developer", "Perl", "Ruby", "Java", "Python", "Catacomb", "InstallerSandboxes",
    "Trial", "Updates", "Staging", "ContainerManager", "Daemon Containers",

    // Additional System Directories
    "ColorPickers", "Colors", "Compositions", "Contextual Menu Items", "Documentation",
    "DriverExtensions", "Favorites", "FontCollections", "Fonts", "Image Capture",
    "Input Methods", "Jupyter", "Keyboard", "Keyboard Layouts", "Keychains",
    "Managed Preferences", "PDF Services", "Printers", "QuickLook", "Receipts",
    "Screen Savers", "ScriptingAdditions", "Scripts", "Sharing", "Shortcuts",
    "Sounds", "Speech", "Spelling", "Spotlight", "User Pictures", "User Template",
    "Video", "WebServer", "Workflows",

    // Apple Service Bundles (com.apple.*)
    "com.apple.AppleMediaServices", "com.apple.WatchListKit", "com.apple.aiml.instrumentation",
    "com.apple.appleaccountd", "com.apple.bluetooth.services.cloud", "com.apple.bluetoothuser",
    "com.apple.familycircled", "com.apple.iTunesCloud", "com.apple.internal.ck",

    // iCloud & Sync Infrastructure
    "com.apple.cloudpaird", "com.apple.iCloudHelper", "com.apple.nsurlsessiond",
    "com.apple.sbd", "com.apple.touristd",

    // System Agents & Daemons
    "com.apple.AMPLibraryAgent", "com.apple.bird", "com.apple.coreduetd",
    "com.apple.homed", "com.apple.photoanalysisd", "com.apple.routined",
    "com.apple.siriactionsd", "com.apple.suggestd",

    // Frameworks & Runtime (never user-facing)
    "com.apple.AppStoreComponents", "com.apple.ScreenTimeUI",
    "com.apple.TelephonyUtilities", "com.apple.WebInspector"
]

// MARK: - Reverse Search Exclusions

/// Normalized prefixes of files and folders to skip during orphan (reverse) search.
/// These are macOS system items, Apple daemons, and infrastructure that should never
/// be flagged as orphaned third-party app files.
let skipReverse: [String] = [
    // Apple & System
    "apple", "temporary", "btserver", "proapps", "scripteditor", "ilife",
    "livefsd", "siritoday", "addressbook", "animoji", "appstore",
    "askpermission", "callhistory", "clouddocs", "diskimages", "dock",
    "facetime", "fileprovider", "instruments", "knowledge", "mobilesync",
    "syncservices", "homeenergyd", "icloud", "icdd", "networkserviceproxy",
    "familycircle", "geoservices", "installation", "passkit",
    "sharedimagecache", "desktop", "mbuseragent", "swiftpm", "baseband",
    "coresimulator", "photoslegacyupgrade", "photosupgrade", "siritts",
    "ipod", "globalpreferences",

    // Analytics & Telemetry
    "apmanalytics", "apmexperiment", "avatarcache", "byhost",
    "contextstoreagent", "mobilemeaccounts", "mobiledocuments", "mobile",
    "intentbuilderc", "loginwindow", "momc", "replayd", "sharedfilelistd",

    // Build Tools & Compilers
    "clang", "audiocomponent", "csexattrcryptoservice",
    "livetranscriptionagent", "sandboxhelper", "statuskitagent",

    // System Daemons
    "betaenrollmentd", "contentlinkingd", "diagnosticextensionsd", "gamed",
    "heard", "homed", "itunescloudd", "lldb", "mds", "mediaanalysisd",
    "metrickitd", "mobiletimerd", "proactived", "ptpcamerad", "studentd",
    "talagent", "watchlistd", "apptranslocation", "xcrun",

    // Generic Infrastructure
    "ds_store", "caches", "crashreporter", "trash",

    // byMakerCleaner itself (never flag our own files)
    "bymakercleaner",

    // Common SDKs and Shared Components
    "amsdatamigratortool", "arfilecache", "assistant", "chromium",
    "cloudkit", "webkit", "databases", "diagnostic", "cache", "gamekit",
    "homebrew", "logi", "microsoft", "mozilla", "sync", "google",
    "sentinel", "hexnode", "sentry", "tvappservices", "reminders", "pbs",
    "notarytool", "differentialprivacy", "storeassetd", "webpush",
    "storedownloadd", "fsck", "crash", "python", "discrecording",
    "photossearch", "pylint", "jamf", "scopedbookmarkagent", "anonymous",
    "identifier", "isolated", "nobackup", "privacypreservingmeasurement",
    "symbols", "stickersd", "privatecloudcomputed", "tipsd",
    "controlcenter", "contactsd", "staticcheck", "index", "segment",
    "sparkle", "summaryevents", "launchdarkly", "identityservicesd",
    "embeddedbinaryvalidationutility", "aaprofilepicture", "minilauncher",
    "jna", "automator", "locationaccessstored", "spotlight", "cef"
]
