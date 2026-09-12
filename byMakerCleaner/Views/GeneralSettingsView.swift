import SwiftUI

/// General settings panel — accessible from the main app's Settings menu.
/// GPU-safe: no animated pickers or native Toggle switches.
struct GeneralSettingsView: View {
    @ObservedObject private var settings = GeneralSettings.shared
    @StateObject private var caskUpdater = CaskDatabaseUpdater.shared

    var body: some View {
        ScrollView {
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
                
            // ── Cask Database Update ───────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text("Cask Database Update")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Frequency to check for new Cask DB updates.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                let columnsFreq = [GridItem(.adaptive(minimum: 100))]
                LazyVGrid(columns: columnsFreq, spacing: 6) {
                    ForEach(GeneralSettings.CaskUpdateFrequency.allCases, id: \.self) { freq in
                        let isSelected = settings.caskUpdateFrequency == freq
                        Text(freq.label)
                            .font(.caption)
                            .fontWeight(isSelected ? .bold : .regular)
                            .foregroundColor(isSelected ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 5)
                            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                            .onTapGesture { settings.caskUpdateFrequency = freq }
                    }
                }
                .padding(.top, 4)
                
                HStack(spacing: 12) {
                    if case .updateAvailable(let etag) = caskUpdater.state {
                        Button(action: {
                            Task { await caskUpdater.downloadAndInstall(etag: etag) }
                        }) {
                            Text("Download and Install Cask DB")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .background(Color.green.opacity(0.12))
                        .foregroundColor(.green)
                        .cornerRadius(6)
                    } else {
                        Button(action: {
                            Task { await caskUpdater.checkUpdate() }
                        }) {
                            Text("Check Update Cask DB")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .background(Color.accentColor.opacity(0.12))
                        .foregroundColor(.accentColor)
                        .cornerRadius(6)
                        .disabled(caskUpdater.state == .checking || caskUpdater.state == .parsing)
                    }
                    
                    // Status text
                    switch caskUpdater.state {
                    case .idle:
                        if let lastCheck = UserDefaults.standard.object(forKey: "lastCaskCheckDate") as? Date {
                            Text("Last checked: \(lastCheck.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    case .checking:
                        ProgressView().controlSize(.small)
                        Text("Checking...").font(.caption2).foregroundColor(.secondary)
                    case .updateAvailable:
                        Text("New update available!").font(.caption2).foregroundColor(.green)
                    case .upToDate:
                        Text("Database is up to date.").font(.caption2).foregroundColor(.secondary)
                    case .downloading:
                        ProgressView().controlSize(.small)
                        Text("Downloading...").font(.caption2).foregroundColor(.secondary)
                    case .parsing:
                        ProgressView().controlSize(.small)
                        Text("Installing...").font(.caption2).foregroundColor(.secondary)
                    case .success:
                        Text("Successfully updated!").font(.caption2).foregroundColor(.green)
                    case .error(let msg):
                        Text("Error: \(msg)").font(.caption2).foregroundColor(.red)
                    }
                }
                .padding(.top, 8)
            }
            
            Divider()
                .padding(.vertical, 12)

            // ── Contribute ───────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                Text("Contribute to Community")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Help improve app detection by sharing your saved app paths with Homebrew Cask.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 12) {
                    Button(action: exportUserDatabase) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export Database")
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .background(Color.accentColor.opacity(0.12))
                    .foregroundColor(.accentColor)
                    .cornerRadius(6)

                    Link("How to submit?", destination: URL(string: "https://github.com/Homebrew/homebrew-cask/issues")!)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 4)

                Text("1. Export the file to your Downloads folder.\n2. Open the link above and create a new issue or pull request.\n3. Attach your exported JSON file.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            Spacer()
        }
        .padding(20)
        }
        .frame(minWidth: 420, minHeight: 440)
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
