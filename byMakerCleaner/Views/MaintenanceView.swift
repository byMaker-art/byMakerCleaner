import SwiftUI

struct MaintenanceView: View {
    @EnvironmentObject var metricsService: SystemMetricsService
    
    @State private var isRunningRAM = false
    @State private var isRunningDNS = false
    @State private var resultMessage: String?
    
    private var ramInfographic: String {
        let percent = metricsService.metrics.ramPercent
        let totalBlocks = 20
        let filledBlocks = max(0, min(totalBlocks, Int(round(percent * Double(totalBlocks)))))
        let emptyBlocks = totalBlocks - filledBlocks
        return String(repeating: "█", count: filledBlocks) + String(repeating: "░", count: emptyBlocks)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────────
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("[ MAINTENANCE ]")
                        .font(Theme.font(size: 16, weight: .bold))
                        .foregroundColor(Theme.accent)
                    Text("OPTIMIZE SYSTEM PERFORMANCE (REQUIRES ADMIN)")
                        .font(Theme.font(size: 12))
                        .foregroundColor(Theme.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Rectangle().fill(Theme.border).frame(height: 1)
            
            // ── Content ──────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 16) {
                if let result = resultMessage {
                    Text(result.uppercased())
                        .font(Theme.font(size: 12, weight: .bold))
                        .foregroundColor(Theme.success)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface)
                        .border(Theme.success, width: 1)
                }
                
                TerminalCard(title: "MEMORY OPTIMIZATION") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("FREE UP RAM")
                                .font(Theme.font(size: 14, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text("FORCES INACTIVE MEMORY TO BE FREED UP.")
                                .font(Theme.font(size: 10))
                                .foregroundColor(Theme.textMuted)
                            
                            HStack(spacing: 4) {
                                Text("[\(ramInfographic)]")
                                    .font(Theme.font(size: 12))
                                    .foregroundColor(Theme.accent)
                                Text("\(Int(metricsService.metrics.ramPercent * 100))%")
                                    .font(Theme.font(size: 12, weight: .bold))
                                    .foregroundColor(Theme.accent)
                            }
                            .padding(.top, 4)
                        }
                        Spacer()
                        
                        if isRunningRAM {
                            Text("[ EXECUTING... ]")
                                .font(Theme.font(size: 14, weight: .bold))
                                .foregroundColor(Theme.accent)
                        } else {
                            TerminalButton("EXECUTE", icon: "cpu") {
                                runRAM()
                            }
                        }
                    }
                }
                
                TerminalCard(title: "NETWORK OPTIMIZATION") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FLUSH DNS CACHE")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Theme.textPrimary)
                            Text("RESOLVES NETWORK CONNECTION PROBLEMS.")
                                .font(Theme.font(size: 10))
                                .foregroundColor(Theme.textMuted)
                        }
                        Spacer()
                        
                        if isRunningDNS {
                            Text("[ EXECUTING... ]")
                                .font(Theme.font(size: 12, weight: .bold))
                                .foregroundColor(Theme.accent)
                        } else {
                            TerminalButton("EXECUTE", icon: "network") {
                                runDNS()
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .padding(16)
        }
        .background(Theme.background)
    }
    
    private func runRAM() {
        guard !isRunningRAM else { return }
        isRunningRAM = true
        resultMessage = nil
        Task {
            let success = await MaintenanceEngine.shared.runWithPrivileges(.freeRAM)
            isRunningRAM = false
            if success {
                resultMessage = "Successfully freed up RAM."
            }
        }
    }
    
    private func runDNS() {
        guard !isRunningDNS else { return }
        isRunningDNS = true
        resultMessage = nil
        Task {
            let success = await MaintenanceEngine.shared.runWithPrivileges(.flushDNS)
            isRunningDNS = false
            if success {
                resultMessage = "Successfully flushed DNS cache."
            }
        }
    }
}
