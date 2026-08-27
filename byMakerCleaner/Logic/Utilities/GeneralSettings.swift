import Foundation

/// Shared user preferences stored in UserDefaults.
/// Used by both the main app (Settings UI) and Helper (SystemMetricsService).
final class GeneralSettings: ObservableObject {

    // MARK: - Keys

    private enum Keys {
        static let metricsInterval = "metricsRefreshInterval"
    }

    // MARK: - Supported interval options (seconds)

    static let intervalOptions: [Double] = [1, 2, 5, 10, 15, 25, 30, 45, 60]

    static func label(for interval: Double) -> String {
        switch interval {
        case 1:  return "1 sec"
        case 2:  return "2 sec"
        case 5:  return "5 sec"
        case 10: return "10 sec"
        case 15: return "15 sec"
        case 25: return "25 sec"
        case 30: return "30 sec"
        case 45: return "45 sec"
        case 60: return "60 sec"
        default: return "\(Int(interval)) sec"
        }
    }

    // MARK: - Shared suite
    // Both app targets read/write from the same App Group UserDefaults suite.
    // Suite ID must match the App Group registered in project.yml entitlements.
    private static let suite = UserDefaults(suiteName: "com.bymaker.byMakerCleaner.shared")
        ?? UserDefaults.standard

    // MARK: - Published settings

    @Published var metricsInterval: Double {
        didSet {
            GeneralSettings.suite.set(metricsInterval, forKey: Keys.metricsInterval)
        }
    }

    // MARK: - Singleton

    static let shared = GeneralSettings()

    private init() {
        let stored = GeneralSettings.suite.double(forKey: Keys.metricsInterval)
        // Validate stored value; default to 2 sec if not set or invalid
        if GeneralSettings.intervalOptions.contains(stored) {
            metricsInterval = stored
        } else {
            metricsInterval = 2.0
        }
    }

    // MARK: - Static read (for use in non-ObservableObject contexts, e.g. Helper)

    static var currentInterval: Double {
        let stored = suite.double(forKey: Keys.metricsInterval)
        return intervalOptions.contains(stored) ? stored : 2.0
    }
}
