import SwiftUI

struct AppDetailView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            if let app = appState.selectedApp {
                HStack {
                    Text("⬅️ Back")
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .onTapGesture {
                            appState.selectApp(nil)
                        }
                    
                    Spacer()
                    
                    Text(app.appName)
                        .font(.largeTitle)
                    
                    Spacer()
                    
                    Text(app.formattedSize)
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                Divider()
                
                if appState.isScanningJunk {
                    Spacer()
                    Text("Scanning for associated files...")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Spacer()
                } else if appState.selectedAppJunkPaths.isEmpty {
                    Spacer()
                    Text("No associated files found.")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Spacer()
                } else {
                    List(appState.selectedAppJunkPaths, id: \.self) { path in
                        HStack {
                            Text("📄")
                            Text(path.path)
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                        }
                    }
                    
                    Divider()
                    
                    HStack {
                        Spacer()
                        Text("🗑️ Uninstall (\(appState.selectedAppJunkPaths.count + 1) items)")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8) // Safe enough, hopefully
                            .onTapGesture {
                                appState.deleteSelectedApp()
                            }
                        Spacer()
                    }
                    .padding()
                }
            } else {
                Text("Error: No app selected")
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
