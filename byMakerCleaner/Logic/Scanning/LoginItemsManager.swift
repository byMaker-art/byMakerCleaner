import Foundation
import Combine
import OSLog
import AppKit

enum LoginItemType: String, Equatable {
    case app = "App"
    case userAgent = "User Agent"
    case systemAgent = "System Agent"
    case systemDaemon = "System Daemon"
}

struct LoginItemModel: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var path: String
    var type: LoginItemType
    var isEnabled: Bool
    var isHidden: Bool // Only applies to .app
    var label: String? // For agents/daemons
}

@MainActor
final class LoginItemsManager: ObservableObject {
    @Published var items: [LoginItemModel] = []
    @Published var isScanning = false

    init() {}

    func scanAll() {
        guard !isScanning else { return }
        isScanning = true
        
        Task {
            let fetchedItems = await Task.detached(priority: .userInitiated) {
                var results: [LoginItemModel] = []
                results.append(contentsOf: Self.fetchClassicLoginItems())
                results.append(contentsOf: Self.fetchLaunchAgents(at: "\(NSHomeDirectory())/Library/LaunchAgents", type: .userAgent))
                results.append(contentsOf: Self.fetchLaunchAgents(at: "/Library/LaunchAgents", type: .systemAgent))
                results.append(contentsOf: Self.fetchLaunchAgents(at: "/Library/LaunchDaemons", type: .systemDaemon))
                return results
            }.value
            
            self.items = fetchedItems
            self.isScanning = false
        }
    }

    // MARK: - Classic Login Items (Apps) via AppleScript
    private nonisolated static func fetchClassicLoginItems() -> [LoginItemModel] {
        let scriptSource = """
        tell application "System Events"
            set theItems to login items
            set resultList to {}
            repeat with i from 1 to count of theItems
                set currentItem to item i of theItems
                set end of resultList to (name of currentItem & "|||" & hidden of currentItem & "|||" & path of currentItem)
            end repeat
            return resultList
        end tell
        """
        
        var error: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else {
            return []
        }
        let descriptor = script.executeAndReturnError(&error)
        
        var results: [LoginItemModel] = []
        let count = descriptor.numberOfItems
        if count >= 1 {
            for i in 1...count {
                if let itemString = descriptor.atIndex(i)?.stringValue {
                    let parts = itemString.components(separatedBy: "|||")
                    if parts.count >= 3 {
                        let name = parts[0]
                        let hidden = parts[1] == "true"
                        let path = parts[2]
                        results.append(LoginItemModel(name: name, path: path, type: .app, isEnabled: true, isHidden: hidden))
                    }
                }
            }
        }
        return results
    }

    func toggleHiddenForApp(_ item: LoginItemModel) {
        guard item.type == .app else { return }
        let newState = !item.isHidden
        
        let scriptSource = """
        tell application "System Events"
            set theItems to login items
            repeat with currentItem in theItems
                if name of currentItem is "\(item.name)" then
                    set hidden of currentItem to \(newState)
                    return
                end if
            end repeat
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(nil)
            // Optimistic UI update
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index].isHidden = newState
            }
        }
    }

    func removeApp(_ item: LoginItemModel) {
        guard item.type == .app else { return }
        
        let scriptSource = """
        tell application "System Events"
            set theItems to login items
            repeat with currentItem in theItems
                if name of currentItem is "\(item.name)" then
                    delete currentItem
                    return
                end if
            end repeat
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            script.executeAndReturnError(nil)
            items.removeAll(where: { $0.id == item.id })
        }
    }

    // MARK: - Launch Agents & Daemons
    private nonisolated static func fetchLaunchAgents(at path: String, type: LoginItemType) -> [LoginItemModel] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: path) else { return [] }
        
        var results: [LoginItemModel] = []
        for file in files where file.hasSuffix(".plist") {
            let fullPath = (path as NSString).appendingPathComponent(file)
            guard let dict = NSDictionary(contentsOfFile: fullPath) as? [String: Any] else { continue }
            
            let label = dict["Label"] as? String ?? file
            let disabled = dict["Disabled"] as? Bool ?? false
            
            // Name fallback: get filename without extension
            let name = (file as NSString).deletingPathExtension
            
            results.append(LoginItemModel(
                name: name,
                path: fullPath,
                type: type,
                isEnabled: !disabled,
                isHidden: false,
                label: label
            ))
        }
        return results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func toggleAgentEnabled(_ item: LoginItemModel) {
        guard item.type == .userAgent, let label = item.label else { return }
        let newState = !item.isEnabled
        
        // We attempt to toggle via launchctl
        let uid = getuid()
        let command = newState ? "launchctl bootstrap gui/\(uid) \(item.path)" : "launchctl bootout gui/\(uid)/\(label)"
        
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]
        task.launch()
        task.waitUntilExit()
        
        // As a fallback to actually persist across reboots, we can also modify the plist if we have permissions
        if let dict = NSMutableDictionary(contentsOfFile: item.path) {
            dict["Disabled"] = !newState
            dict.write(toFile: item.path, atomically: true)
        }
        
        // Optimistic UI update
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index].isEnabled = newState
        }
    }
    
    func openSystemSettingsLoginItems() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
}
