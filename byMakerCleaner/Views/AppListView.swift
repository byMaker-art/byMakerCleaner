import SwiftUI

struct AppListView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            HStack {
                Text("Installed Applications")
                    .font(.largeTitle)
                    .padding()
                
                Spacer()
                
                if appState.isLoadingApps {
                    Text("Scanning...")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    Text("Rescan")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .onTapGesture {
                            appState.loadInstalledApps()
                        }
                        .padding()
                }
            }
            
            Divider()
            
            if appState.isLoadingApps && appState.installedApps.isEmpty {
                Spacer()
                Text("Looking for apps...")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                List(appState.installedApps) { app in
                    HStack {
                        // Safe functional icon representation (no SF Symbol)
                        Text("📱")
                            .font(.title)
                        
                        VStack(alignment: .leading) {
                            Text(app.appName)
                                .font(.headline)
                            Text(app.bundleIdentifier)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(app.formattedSize)
                            .font(.subheadline)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            if appState.installedApps.isEmpty {
                appState.loadInstalledApps()
            }
        }
    }
}
