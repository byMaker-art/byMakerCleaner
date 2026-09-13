import SwiftUI

/// AppDetailView — shows details of the selected app for uninstallation.
/// Redesigned to match Retro Terminal style.
/// GPU-safe: Text + .onTapGesture only.
struct AppDetailView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Rectangle().fill(Theme.border).frame(height: 1)
            
            if appState.selectedApp != nil {
                contentArea
            } else {
                Spacer()
                Text("[ ERROR: NO APP SELECTED ]")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundColor(Theme.destructive)
                Spacer()
            }
        }
        .background(Theme.background)
        .frame(minWidth: 500, minHeight: 400)
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            TerminalButton("< BACK", icon: nil) {
                appState.selectApp(nil)
            }
            
            Spacer()
            
            if let app = appState.selectedApp {
                Text("[ " + app.appName.uppercased() + " ]")
                    .font(Theme.font(size: 16, weight: .bold))
                    .foregroundColor(Theme.accent)
                
                Spacer()
                
                Text(app.formattedSize)
                    .font(Theme.font(size: 12))
                    .foregroundColor(Theme.textMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentArea: some View {
        if appState.isScanningJunk {
            Spacer()
            Text("[ SCANNING FOR ASSOCIATED FILES... ]")
                .font(Theme.font(size: 14, weight: .bold))
                .foregroundColor(Theme.textMuted)
            Spacer()
        } else if appState.selectedAppJunkPaths.isEmpty {
            Spacer()
            Text("[ NO ASSOCIATED FILES FOUND ]")
                .font(Theme.font(size: 14, weight: .bold))
                .foregroundColor(Theme.textMuted)
            Spacer()
        } else {
            List(appState.selectedAppJunkPaths, id: \.self) { path in
                HStack {
                    Text(">")
                        .font(Theme.font(size: 12, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text(path.path)
                        .font(Theme.font(size: 11))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .listRowBackground(Theme.background)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .listStyle(.plain)
            .background(Theme.background)
            .scrollContentBackground(.hidden)
            
            Rectangle().fill(Theme.border).frame(height: 1)
            
            HStack {
                Spacer()
                let itemsCount = appState.selectedAppJunkPaths.count + 1
                Text("[ UNINSTALL (\(itemsCount) ITEMS) ]")
                    .font(Theme.font(size: 14, weight: .bold))
                    .foregroundColor(Theme.background)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Theme.destructive)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        appState.deleteSelectedApp()
                    }
                Spacer()
            }
            .padding()
            .background(Theme.surface)
        }
    }
}
