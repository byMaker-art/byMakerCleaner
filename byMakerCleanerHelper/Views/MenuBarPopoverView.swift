import SwiftUI

/// Compact popover shown when user clicks the menu bar icon.
/// All interactions via Text + .onTapGesture (GPU-safe, no Button).
struct MenuBarPopoverView: View {
    @EnvironmentObject var metricsService: SystemMetricsService

    private var m: SystemMetrics { metricsService.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Divider().padding(.vertical, 4)
            metricSection
            Divider().padding(.vertical, 4)
            footerRow
        }
        .padding(14)
        .frame(width: 260)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("byMaker Cleaner")
                .font(.headline)
            Spacer()
            Text("●")
                .foregroundColor(.green)
                .font(.caption)
            Text("Active")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Metrics

    private var metricSection: some View {
        VStack(spacing: 10) {
            metricRow(
                icon: "💻",
                label: "CPU",
                value: "\(m.cpuPercent)%",
                barValue: m.cpuUsage,
                barColor: barColor(for: m.cpuUsage)
            )
            metricRow(
                icon: "🧠",
                label: "RAM",
                value: "\(m.formatted(bytes: m.ramUsed)) / \(m.formatted(bytes: m.ramTotal))",
                barValue: m.ramPercent,
                barColor: barColor(for: m.ramPercent)
            )
            metricRow(
                icon: "💾",
                label: "Disk",
                value: "\(m.formatted(bytes: m.diskFree)) free",
                barValue: m.diskPercent,
                barColor: barColor(for: m.diskPercent)
            )
            networkRow
        }
    }

    private func metricRow(
        icon: String,
        label: String,
        value: String,
        barValue: Double,
        barColor: Color
    ) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(icon)
                Text(label)
                    .font(.subheadline).bold()
                Spacer()
                Text(value)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 5)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * min(max(barValue, 0), 1), height: 5)
                }
            }
            .frame(height: 5)
        }
    }

    private var networkRow: some View {
        HStack {
            Text("📡")
            Text("Network")
                .font(.subheadline).bold()
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    Text("↑")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(m.formattedSpeed(m.netUpBytesPerSec))
                        .font(.caption)
                        .monospacedDigit()
                }
                HStack(spacing: 4) {
                    Text("↓")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(m.formattedSpeed(m.netDownBytesPerSec))
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack {
            Text("Open byMaker Cleaner")
                .font(.caption)
                .foregroundColor(.accentColor)
                .onTapGesture { openMainApp() }
            Spacer()
            Text("Quit")
                .font(.caption)
                .foregroundColor(.secondary)
                .onTapGesture { NSApplication.shared.terminate(nil) }
        }
    }

    // MARK: - Helpers

    private func barColor(for value: Double) -> Color {
        switch value {
        case ..<0.6:  return .green
        case ..<0.8:  return .yellow
        default:      return .red
        }
    }

    private func openMainApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.bymaker.byMakerCleaner") {
            let configuration = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
        } else {
            // Fallback for development if bundle ID isn't found
            NSWorkspace.shared.launchApplication("byMakerCleaner")
        }
    }
}
