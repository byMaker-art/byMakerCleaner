import SwiftUI

/// Compact popover shown when user clicks the menu bar icon.
/// All interactions via Text + .onTapGesture (GPU-safe, no Button).
/// Note: Settings button now works natively (same process as main app).
struct MenuBarPopoverView: View {
    @EnvironmentObject var metricsService: SystemMetricsService
    @EnvironmentObject var bluetoothService: BluetoothService
    @EnvironmentObject var healthService: HealthService
    @Environment(\.openWindow) private var openWindow

    @State private var showAllBluetooth = false

    private var m: SystemMetrics { metricsService.metrics }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 8)
            
            HealthGaugeView(score: healthService.score)
            
            Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 8)
            
            metricSection
            
            Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 8)
            
            actionSection
            
            if !bluetoothService.pairedDevices.isEmpty {
                Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 8)
                bluetoothSection
            }
            
            Rectangle().fill(Theme.border).frame(height: 1).padding(.vertical, 8)
            footerRow
        }
        .padding(14)
        .frame(width: 280)
        .background(Theme.background)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack {
            Text("[ BYMAKER ]")
                .font(Theme.font(size: 14, weight: .bold))
                .foregroundColor(Theme.accent)
            Spacer()
            Text("●")
                .foregroundColor(Theme.success)
                .font(.caption)
            Text("ACTIVE")
                .font(Theme.font(size: 10))
                .foregroundColor(Theme.textMuted)
        }
    }

    // MARK: - Metrics

    private var metricSection: some View {
        VStack(spacing: 12) {
            metricRow(
                icon: "💻",
                label: "CPU",
                value: "",
                barValue: m.cpuUsage,
                barColor: barColor(for: m.cpuUsage)
            )
            
            ramMetricRow
            
            metricRow(
                icon: "💾",
                label: "DISK",
                value: "\(m.formatted(bytes: m.diskFree)) FREE",
                barValue: m.diskPercent,
                barColor: barColor(for: m.diskPercent)
            )
            
            networkRow
        }
    }

    private var ramMetricRow: some View {
        VStack(spacing: 4) {
            HStack {
                Text("🧠")
                Text("RAM")
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(m.formatted(bytes: m.ramUsed)) / \(m.formatted(bytes: m.ramTotal))")
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
                
                Text("[ FREE ]")
                    .font(Theme.font(size: 10, weight: .bold))
                    .foregroundColor(Theme.background)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.accent)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        Task { await MaintenanceEngine.shared.freeUpRAM() }
                    }
            }
            
            HStack {
                TerminalProgress(value: m.ramPercent, totalLength: 22, color: barColor(for: m.ramPercent))
                Spacer()
            }
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
                Text(label.uppercased())
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text(value.uppercased())
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
            }
            HStack {
                TerminalProgress(value: barValue, totalLength: 22, color: barColor)
                Spacer()
            }
        }
    }

    private var networkRow: some View {
        HStack {
            Text("📡")
            Text("NETWORK")
                .font(Theme.font(size: 12, weight: .bold))
                .foregroundColor(Theme.textPrimary)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: 4) {
                    Text("↑")
                        .font(Theme.font(size: 10))
                        .foregroundColor(Theme.textMuted)
                    Text(m.formattedSpeed(m.netUpBytesPerSec))
                        .font(Theme.font(size: 10))
                        .foregroundColor(Theme.textPrimary)
                }
                HStack(spacing: 4) {
                    Text("↓")
                        .font(Theme.font(size: 10))
                        .foregroundColor(Theme.textMuted)
                    Text(m.formattedSpeed(m.netDownBytesPerSec))
                        .font(Theme.font(size: 10))
                        .foregroundColor(Theme.textPrimary)
                }
            }
        }
    }

    // MARK: - Actions
    
    private var actionSection: some View {
        HStack {
            Spacer()
            TerminalButton("SCREENSHOT", icon: "camera") {
                ScreenshotService.shared.captureInteractiveToClipboard()
            }
            Spacer()
        }
    }
    
    // MARK: - Bluetooth
    
    private var bluetoothSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(showAllBluetooth ? "[-]" : "[+]")
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text("BLUETOOTH")
                    .font(Theme.font(size: 12, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showAllBluetooth.toggle()
            }
            
            let devices = showAllBluetooth ? bluetoothService.pairedDevices : bluetoothService.pairedDevices.filter { $0.isConnected }
            
            if devices.isEmpty && !showAllBluetooth {
                Text("NO ACTIVE DEVICES")
                    .font(Theme.font(size: 10))
                    .foregroundColor(Theme.textMuted)
            } else {
                ForEach(devices) { device in
                    HStack {
                        Text(device.name.uppercased())
                            .font(Theme.font(size: 10))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Text(device.isConnected ? "[ON]" : "[OFF]")
                            .foregroundColor(device.isConnected ? Theme.success : Theme.textMuted)
                            .font(Theme.font(size: 10, weight: .bold))
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack(spacing: 12) {
            Text("[ OPEN APP ]")
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(Theme.accent)
                .onTapGesture { openMainWindow() }

            if #available(macOS 14, *) {
                SettingsOpenerLabel()
            } else {
                Text("[ SETTINGS ]")
                    .font(Theme.font(size: 10, weight: .bold))
                    .foregroundColor(Theme.accent)
                    .onTapGesture {
                        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    }
            }

            Spacer()

            Text("[ QUIT ]")
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(Theme.destructive)
                .onTapGesture { NSApplication.shared.terminate(nil) }
        }
    }

    // MARK: - Helpers

    private func barColor(for value: Double) -> Color {
        switch value {
        case ..<0.6:  return Theme.success
        case ..<0.8:  return Theme.warning
        default:      return Theme.destructive
        }
    }

    /// Bring the main ContentView window to front or open it if it was closed.
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: "main")
    }
}

// MARK: - Settings Opener (macOS 14+)

@available(macOS 14.0, *)
private struct SettingsOpenerLabel: View {
    var body: some View {
        SettingsLink {
            Text("[ SETTINGS ]")
                .font(Theme.font(size: 10, weight: .bold))
                .foregroundColor(Theme.accent)
        }
        .buttonStyle(.plain)
    }
}
