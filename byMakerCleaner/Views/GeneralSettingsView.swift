import SwiftUI

/// General settings panel — accessible from the main app's Settings menu.
/// GPU-safe: no animated pickers or native Toggle switches.
struct GeneralSettingsView: View {
    @ObservedObject private var settings = GeneralSettings.shared
    @StateObject private var caskUpdater = CaskDatabaseUpdater.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
            Text("[ GENERAL SETTINGS ]")
                .font(Theme.font(size: 16, weight: .bold))
                .foregroundColor(Theme.accent)
                .padding(.bottom, 12)

            Rectangle().fill(Theme.border).frame(height: 1)
                .padding(.bottom, 12)

            // ── Metrics Refresh Interval ─────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("METRICS REFRESH INTERVAL")
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("HOW OFTEN THE MENU-BAR HELPER POLLS CPU, RAM, DISK AND NETWORK.")
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)

                // Grid of interval buttons (GPU-safe: no Picker)
                let columns = [GridItem(.adaptive(minimum: 70))]
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(GeneralSettings.intervalOptions, id: \.self) { interval in
                        let isSelected = settings.metricsInterval == interval
                        Text(GeneralSettings.label(for: interval).uppercased())
                            .font(Theme.font(size: 12, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? Theme.background : Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(isSelected ? Theme.accent : Theme.surface)
                            .border(isSelected ? Theme.accent : Theme.border, width: 1)
                            .onTapGesture { settings.metricsInterval = interval }
                    }
                }
                .padding(.top, 4)
            }

            Rectangle().fill(Theme.border).frame(height: 1)
                .padding(.vertical, 12)
                
            // ── Cask Database Update ───────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("CASK DATABASE UPDATE")
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("FREQUENCY TO CHECK FOR NEW CASK DB UPDATES.")
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
                    
                let columnsFreq = [GridItem(.adaptive(minimum: 100))]
                LazyVGrid(columns: columnsFreq, spacing: 6) {
                    ForEach(GeneralSettings.CaskUpdateFrequency.allCases, id: \.self) { freq in
                        let isSelected = settings.caskUpdateFrequency == freq
                        Text(freq.label.uppercased())
                            .font(Theme.font(size: 12, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? Theme.background : Theme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(isSelected ? Theme.accent : Theme.surface)
                            .border(isSelected ? Theme.accent : Theme.border, width: 1)
                            .onTapGesture { settings.caskUpdateFrequency = freq }
                    }
                }
                .padding(.top, 4)
                
                HStack(spacing: 12) {
                    if case .updateAvailable(let etag) = caskUpdater.state {
                        TerminalButton("DOWNLOAD & INSTALL", icon: "arrow.down.circle") {
                            Task { await caskUpdater.downloadAndInstall(etag: etag) }
                        }
                    } else {
                        let isBusy = caskUpdater.state == .checking || caskUpdater.state == .parsing
                        TerminalButton("CHECK UPDATE", icon: "arrow.triangle.2.circlepath") {
                            if !isBusy { Task { await caskUpdater.checkUpdate() } }
                        }
                        .opacity(isBusy ? 0.5 : 1.0)
                    }
                    
                    // Status text
                    switch caskUpdater.state {
                    case .idle:
                        if let lastCheck = UserDefaults.standard.object(forKey: "lastCaskCheckDate") as? Date {
                            Text("LAST CHECKED: \(lastCheck.formatted(date: .abbreviated, time: .shortened).uppercased())")
                                .font(Theme.font(size: 10))
                                .foregroundColor(Theme.textMuted)
                        }
                    case .checking:
                        Text("[ CHECKING... ]").font(Theme.font(size: 10)).foregroundColor(Theme.textMuted)
                    case .updateAvailable:
                        Text("[ NEW UPDATE AVAILABLE! ]").font(Theme.font(size: 10)).foregroundColor(Theme.success)
                    case .upToDate:
                        Text("[ DB UP TO DATE ]").font(Theme.font(size: 10)).foregroundColor(Theme.textMuted)
                    case .downloading:
                        Text("[ DOWNLOADING... ]").font(Theme.font(size: 10)).foregroundColor(Theme.textMuted)
                    case .parsing:
                        Text("[ INSTALLING... ]").font(Theme.font(size: 10)).foregroundColor(Theme.textMuted)
                    case .success:
                        Text("[ SUCCESSFULLY UPDATED! ]").font(Theme.font(size: 10)).foregroundColor(Theme.success)
                    case .error(let msg):
                        Text("[ ERROR: \(msg.uppercased()) ]").font(Theme.font(size: 10)).foregroundColor(Theme.destructive)
                    }
                }
                .padding(.top, 8)
            }
            
            Rectangle().fill(Theme.border).frame(height: 1)
                .padding(.vertical, 12)

            // ── Contribute ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                Text("CONTRIBUTE TO COMMUNITY")
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("HELP IMPROVE APP DETECTION BY SHARING YOUR SAVED APP PATHS WITH HOMEBREW CASK.")
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
                
                HStack(spacing: 12) {
                    TerminalButton("EXPORT DATABASE", icon: "square.and.arrow.up") {
                        exportUserDatabase()
                    }

                    Link("[ HOW TO SUBMIT? ]", destination: URL(string: "https://github.com/Homebrew/homebrew-cask/issues")!)
                        .font(Theme.font(size: 10, weight: .bold))
                        .foregroundColor(Theme.accent)
                }
                .padding(.top, 4)

                Text("1. EXPORT THE FILE TO YOUR DOWNLOADS FOLDER.\n2. OPEN THE LINK ABOVE AND CREATE A NEW ISSUE OR PULL REQUEST.\n3. ATTACH YOUR EXPORTED JSON FILE.")
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding(20)
        }
        .frame(minWidth: 420, minHeight: 440)
        .background(Theme.background)
    }
    
    private func exportUserDatabase() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let sourceURL = appSupport.appendingPathComponent("byMakerCleaner").appendingPathComponent("UserDatabase.json")
        
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }
        
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: Date())
        
        let destURL = downloads.appendingPathComponent("byMakerCleaner_UserDB_\(dateString).json")
        
        try? FileManager.default.removeItem(at: destURL)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            NSWorkspace.shared.activateFileViewerSelecting([destURL])
        } catch {
            print("Export failed: \(error)")
        }
    }
}
