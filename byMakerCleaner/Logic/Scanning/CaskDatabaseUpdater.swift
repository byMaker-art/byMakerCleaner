import Foundation
import Combine

struct ParsedCaskDB: Codable {
    let zapPaths: [String: [String]]
    let bundleIDPaths: [String: [String]]
}

@MainActor
final class CaskDatabaseUpdater: ObservableObject {
    static let shared = CaskDatabaseUpdater()
    
    enum State: Equatable {
        case idle
        case checking
        case updateAvailable(etag: String)
        case upToDate
        case downloading(progress: Double)
        case parsing
        case success
        case error(String)
    }
    
    @Published var state: State = .idle
    
    private let apiURL = URL(string: "https://formulae.brew.sh/api/cask.json")!
    
    private var fileURL: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("byMakerCleaner")
        if !FileManager.default.fileExists(atPath: appDir.path) {
            try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        }
        return appDir.appendingPathComponent("ParsedCaskDB.json")
    }
    
    func checkUpdate() async {
        state = .checking
        var request = URLRequest(url: apiURL)
        request.httpMethod = "HEAD"
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               let etag = httpResponse.allHeaderFields["Etag"] as? String ?? httpResponse.allHeaderFields["ETag"] as? String {
                
                let savedEtag = UserDefaults.standard.string(forKey: "lastCaskETag")
                if savedEtag != etag {
                    state = .updateAvailable(etag: etag)
                } else {
                    state = .upToDate
                    UserDefaults.standard.set(Date(), forKey: "lastCaskCheckDate")
                }
            } else {
                state = .error("No ETag found in response")
            }
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    func downloadAndInstall(etag: String) async {
        state = .downloading(progress: 0.0) // progress not implemented yet, using placeholder
        
        do {
            let (data, response) = try await URLSession.shared.data(from: apiURL)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                state = .error("Failed to download")
                return
            }
            
            state = .parsing
            
            let parsedDB = try await Task.detached(priority: .userInitiated) { () -> ParsedCaskDB in
                let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] ?? []
                var db: [String: [String]] = [:]
                var bundleDB: [String: [String]] = [:]
                
                func normalize(_ key: String) -> String {
                    var n = key.lowercased()
                    if n.hasSuffix(".app") {
                        n = String(n.dropLast(4))
                    }
                    return n
                }
                
                for cask in jsonArray {
                    var zapPaths: [String] = []
                    var appNames: [String] = []
                    var bundleIDs: [String] = []
                    
                    if let artifacts = cask["artifacts"] as? [[String: Any]] {
                        for artifact in artifacts {
                            if let apps = artifact["app"] as? [String] {
                                for app in apps where app.hasSuffix(".app") {
                                    appNames.append(app)
                                }
                            } else if let apps = artifact["app"] as? [[String: Any]] {
                                // sometimes app is an array of dicts where each dict might have keys, or it's just array of strings.
                                // wait, artifacts is a list of dicts. e.g. [{"app": ["Name.app"]}]
                                // or [{"app": ["Name.app", {"target": "..."}]}]
                                for appEntry in apps {
                                    if let appName = appEntry["target"] as? String, appName.hasSuffix(".app") {
                                        appNames.append(appName)
                                    } else if let appName = appEntry.keys.first, appName.hasSuffix(".app") {
                                        // Usually it's just array of strings or array with strings and dicts. 
                                        // Actually `[String]` cast might fail if there's a dict. We must iterate as `[Any]`.
                                    }
                                }
                            }
                            
                            // Let's do it safely
                            if let apps = artifact["app"] as? [Any] {
                                for app in apps {
                                    if let appStr = app as? String, appStr.hasSuffix(".app") {
                                        appNames.append(appStr)
                                    } else if let appDict = app as? [String: Any], let target = appDict["target"] as? String, target.hasSuffix(".app") {
                                        appNames.append(target)
                                    }
                                }
                            }
                            
                            if let zaps = artifact["zap"] as? [[String: Any]] {
                                for zap in zaps {
                                    if let trash = zap["trash"] {
                                        if let p = trash as? String { zapPaths.append(p) }
                                        else if let ps = trash as? [String] { zapPaths.append(contentsOf: ps) }
                                    }
                                }
                            }
                            
                            if let uninstalls = artifact["uninstall"] as? [[String: Any]] {
                                for uninst in uninstalls {
                                    if let quit = uninst["quit"] {
                                        if let q = quit as? String { bundleIDs.append(q) }
                                        else if let qs = quit as? [String] { bundleIDs.append(contentsOf: qs) }
                                    }
                                }
                            }
                        }
                    }
                    
                    if !zapPaths.isEmpty {
                        var keys = Set<String>()
                        for app in appNames { keys.insert(normalize(app)) }
                        if let names = cask["name"] as? [String] {
                            for n in names { keys.insert(normalize(n)) }
                        }
                        
                        let uniqueZaps = Array(Set(zapPaths))
                        
                        for key in keys {
                            db[key] = uniqueZaps
                        }
                        
                        for bid in bundleIDs {
                            bundleDB[bid.lowercased()] = uniqueZaps
                        }
                    }
                }
                return ParsedCaskDB(zapPaths: db, bundleIDPaths: bundleDB)
            }.value
            
            let encoded = try JSONEncoder().encode(parsedDB)
            try encoded.write(to: fileURL, options: .atomic)
            
            CaskDatabase.shared.reload(from: parsedDB)
            migrateUserDB(parsedDB: parsedDB)
            
            UserDefaults.standard.set(etag, forKey: "lastCaskETag")
            UserDefaults.standard.set(Date(), forKey: "lastCaskCheckDate")
            
            state = .success
            
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if state == .success { state = .idle }
            }
            
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    private func migrateUserDB(parsedDB: ParsedCaskDB) {
        UserDatabase.shared.migrateToCaskDB(caskZapPaths: parsedDB.zapPaths, caskBundleIDPaths: parsedDB.bundleIDPaths)
    }
}
