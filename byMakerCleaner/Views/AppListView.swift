import SwiftUI

/// App Uninstaller — lists installed apps with size info.
/// UI style matches OrphanFinderView: header bar + list + tap-to-detail.
/// GPU-safe: Text + .onTapGesture only.
struct AppListView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
        }
        .onAppear {
            if appState.installedApps.isEmpty {
                appState.loadInstalledApps()
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("📱 App Uninstaller")
                    .font(.headline)
                Text("Find and remove installed applications")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if !appState.installedApps.isEmpty {
                Text("\(appState.installedApps.count) apps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            rescanButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var rescanButton: some View {
        let isLoading = appState.isLoadingApps
        return Text(isLoading ? "Scanning..." : "Rescan")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(isLoading ? .secondary : .accentColor)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Color.accentColor.opacity(isLoading ? 0.05 : 0.12))
            .cornerRadius(6)
            .onTapGesture { if !isLoading { appState.loadInstalledApps() } }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentArea: some View {
        if appState.isLoadingApps && appState.installedApps.isEmpty {
            VStack(spacing: 12) {
                Text("🔍").font(.system(size: 40))
                Text("Looking for installed apps...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if appState.installedApps.isEmpty {
            VStack(spacing: 12) {
                Text("📭").font(.system(size: 40))
                Text("No applications found.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            appList
        }
    }

    // MARK: - App list

    private var appList: some View {
        List(appState.installedApps) { app in
            appRow(app)
                .listRowSeparator(.visible)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .contentShape(Rectangle())
                .onTapGesture { appState.selectApp(app) }
        }
        .listStyle(.plain)
    }

    private func appRow(_ app: InstalledApp) -> some View {
        HStack(spacing: 10) {
            // App icon (system icon, GPU-safe as NSImage render)
            Image(nsImage: app.icon)
                .resizable()
                .frame(width: 32, height: 32)

            // Name + bundle ID
            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .font(.subheadline)
                    .bold()
                    .lineLimit(1)
                Text(app.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Size
            Text(app.formattedSize)
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)

            // Uninstall chevron hint
            Text("›")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}
