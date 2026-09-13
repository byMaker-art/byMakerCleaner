import Foundation

final class HealthScoreCalculator: Sendable {
    static let shared = HealthScoreCalculator()
    
    private init() {}
    
    /// Calculates a health score from 0 to 100
    func calculateScore() -> Int {
        var score = 100
        
        // 1. Disk Space
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
           let total = attrs[.systemSize] as? Int64,
           let free = attrs[.systemFreeSize] as? Int64,
           total > 0 {
            let freePercent = Double(free) / Double(total)
            if freePercent < 0.10 {
                score -= 30
            } else if freePercent < 0.20 {
                score -= 15
            }
        }
        
        // 2. Days since last clean
        let lastCleanDate = UserDefaults.standard.object(forKey: "lastCleanDate") as? Date ?? Date.distantPast
        let daysSinceClean = Calendar.current.dateComponents([.day], from: lastCleanDate, to: Date()).day ?? 30
        
        if daysSinceClean > 14 {
            score -= 20
        } else if daysSinceClean > 7 {
            score -= 10
        }
        
        // Ensure score stays within 0-100 bounds
        return max(0, min(100, score))
    }
}
