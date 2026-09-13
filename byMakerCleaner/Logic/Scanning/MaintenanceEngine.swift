import Foundation
import Cocoa

@MainActor
final class MaintenanceEngine {
    static let shared = MaintenanceEngine()
    
    private init() {}
    
    enum MaintenanceAction {
        case freeRAM
        case flushDNS
        
        var command: String {
            switch self {
            case .freeRAM:
                return "purge"
            case .flushDNS:
                return "dscacheutil -flushcache; killall -HUP mDNSResponder"
            }
        }
        
        var title: String {
            switch self {
            case .freeRAM: return "Free Up RAM"
            case .flushDNS: return "Flush DNS Cache"
            }
        }
    }
    
    /// Executes a shell command with root privileges via AppleScript
    func runWithPrivileges(_ action: MaintenanceAction) async -> Bool {
        let script = "do shell script \"\(action.command)\" with administrator privileges"
        
        return await Task.detached {
            let appleScript = NSAppleScript(source: script)
            var errorInfo: NSDictionary?
            let result = appleScript?.executeAndReturnError(&errorInfo)
            
            if let errorInfo = errorInfo {
                print("Maintenance error (\(action.title)): \(errorInfo)")
                return false
            }
            
            return result != nil
        }.value
    }
    
    func freeUpRAM() async {
        _ = await runWithPrivileges(.freeRAM)
    }
    
    func flushDNS() async {
        _ = await runWithPrivileges(.flushDNS)
    }
}
