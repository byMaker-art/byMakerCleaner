import SwiftUI

/// General settings panel — accessible from the main app's Settings menu.
/// GPU-safe: no animated pickers or native Toggle switches.
struct GeneralSettingsView: View {
    @ObservedObject private var settings = GeneralSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("General Settings")
                .font(.headline)
                .padding(.bottom, 12)

            Divider()
                .padding(.bottom, 12)

            // ── Metrics Refresh Interval ─────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("Metrics Refresh Interval")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("How often the menu-bar Helper polls CPU, RAM, Disk and Network.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Grid of interval buttons (GPU-safe: no Picker)
                let columns = [GridItem(.adaptive(minimum: 70))]
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(GeneralSettings.intervalOptions, id: \.self) { interval in
                        let isSelected = settings.metricsInterval == interval
                        Text(GeneralSettings.label(for: interval))
                            .font(.caption)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(isSelected
                                        ? Color.accentColor
                                        : Color(NSColor.controlBackgroundColor))
                            .onTapGesture { settings.metricsInterval = interval }
                    }
                }
                .padding(.top, 4)
            }

            Divider()
                .padding(.vertical, 12)

            // ── Contribute ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("Contribute to Community")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Help improve app detection by sharing your saved app paths with Homebrew Cask.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: exportUserDatabase) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export User Database")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .background(Color.accentColor.opacity(0.12))
                .foregroundColor(.accentColor)
                .cornerRadius(6)
                .padding(.top, 4)
            }

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 320)
    }
    
    private func exportUserDatabase() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let sourceURL = appSupport.appendingPathComponent("byMakerCleaner").appendingPathComponent("UserDatabase.json")
        
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let destURL = desktop.appendingPathComponent("byMakerCleaner_UserDB_Export.json")
        
        try? FileManager.default.removeItem(at: destURL)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            NSWorkspace.shared.activateFileViewerSelecting([destURL])
            
            if let url = URL(string: "https://github.com/Homebrew/homebrew-cask/issues") {
                NSWorkspace.shared.open(url)
            }
        } catch {
            print("Export failed: \(error)")
        }
    }
}
