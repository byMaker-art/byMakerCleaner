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
        }
    }
}
