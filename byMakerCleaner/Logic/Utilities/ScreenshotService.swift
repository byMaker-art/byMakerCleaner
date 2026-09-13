import Foundation
import Cocoa

final class ScreenshotService: Sendable {
    static let shared = ScreenshotService()
    
    private init() {}
    
    /// Triggers the interactive screenshot tool and saves to clipboard
    func captureInteractiveToClipboard() {
        Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-i", "-c"] // -i: interactive, -c: save to clipboard
            do {
                try process.run()
                // Do not wait for it to finish in UI thread
            } catch {
                print("Failed to run screencapture: \(error.localizedDescription)")
            }
        }
    }
}
