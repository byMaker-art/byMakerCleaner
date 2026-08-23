import SwiftUI

@main
struct byMakerCleanerApp: App {
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("byMakerCleaner")
                    .font(.largeTitle)
                    .padding()
                
                Text("Functional MVP - Hello World")
                    .font(.title2)
            }
            .frame(width: 400, height: 300)
            .task {
                print("Starting background scan of installed apps...")
                let apps = AppInfoFetcher.shared.fetchInstalledApps()
                print("Scan complete! Found \(apps.count) apps.")
                for app in apps.prefix(5) {
                    print(" - \(app.appName) (\(app.formattedSize))")
                }
            }
        }
    }
}
