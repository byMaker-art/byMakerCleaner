import Foundation

struct UserAppRecord: Codable {
    let bundleID: String
    let appName: String
    let paths: [String]
    let addedAt: Date
}

final class UserDatabase: @unchecked Sendable {
    static let shared = UserDatabase()
    
    private var records: [String: UserAppRecord] = [:]
    private let lock = NSLock()
    
    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("byMakerCleaner")
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent("UserDatabase.json")
    }
    
    private init() {
        load()
    }
    
    func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([String: UserAppRecord].self, from: data) else {
            return
        }
        lock.lock()
        self.records = decoded
        lock.unlock()
    }
    
    func save(app: InstalledApp, paths: [URL]) {
        let home = NSHomeDirectory()
        // Convert exact absolute paths to paths with ~ if they are in home directory
        // This is better for portability (if user changes username or moves DB)
        let stringPaths = paths.map { url -> String in
            let p = url.path
            if p.hasPrefix(home) {
                return "~" + p.dropFirst(home.count)
            }
            return p
        }
        
        let record = UserAppRecord(
            bundleID: app.bundleIdentifier,
            appName: app.appName,
            paths: stringPaths,
            addedAt: Date()
        )
        
        lock.lock()
        records[app.bundleIdentifier] = record
        let currentRecords = records
        lock.unlock()
        
        if let encoded = try? JSONEncoder().encode(currentRecords) {
            try? encoded.write(to: fileURL, options: .atomic)
        }
    }
    
    func paths(for bundleID: String) -> [String]? {
        lock.lock()
        defer { lock.unlock() }
        return records[bundleID]?.paths
    }
}
