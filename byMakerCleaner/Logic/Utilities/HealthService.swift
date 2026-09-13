import Foundation
import Combine
import UserNotifications

@MainActor
final class HealthService: ObservableObject {
    @Published var score: Int = 100
    
    private var timer: Timer?
    
    init() {
        start()
    }
    
    func start() {
        requestPermissions()
        refresh()
        // Check periodically, e.g., every 4 hours. Using 1 hour here for standard checking.
        timer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func refresh() {
        let newScore = HealthScoreCalculator.shared.calculateScore()
        score = newScore
        
        // Check if we need to notify (Score < 40%)
        let lastNotified = UserDefaults.standard.object(forKey: "lastHealthNotificationDate") as? Date ?? Date.distantPast
        let hoursSinceNotification = Calendar.current.dateComponents([.hour], from: lastNotified, to: Date()).hour ?? 25
        
        // Notify at most once a day
        if score < 40 && hoursSinceNotification >= 24 {
            sendNotification()
            UserDefaults.standard.set(Date(), forKey: "lastHealthNotificationDate")
        }
    }
    
    private func requestPermissions() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        }
    }
    
    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Mac Health Alert"
        content.body = "Your Mac's health score dropped to \(score)%. We recommend running a Smart Scan or freeing up space."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "HealthAlert", content: content, trigger: nil)
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
