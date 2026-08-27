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

            // ── Future settings go here ──────────────────────────────
            Text("More settings coming soon.")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 260)
    }
}
