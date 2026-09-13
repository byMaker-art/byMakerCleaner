import SwiftUI

struct MaintenanceView: View {
    @State private var isRunningRAM = false
    @State private var isRunningDNS = false
    @State private var resultMessage: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Maintenance")
                .font(.largeTitle)
                .bold()
                .padding(.bottom, 10)
            
            Text("Optimize your system's performance. These tasks require administrator privileges.")
                .foregroundColor(.secondary)
            
            if let result = resultMessage {
                Text(result)
                    .foregroundColor(.green)
                    .padding(8)
                    .background(Color.green.opacity(0.2))
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                // Free Up RAM
                HStack {
                    VStack(alignment: .leading) {
                        Text("Free Up RAM")
                            .font(.headline)
                        Text("Forces inactive memory to be freed up. Helpful if your Mac feels sluggish after heavy use.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if isRunningRAM {
                        Text("[████░░░░]")
                            .foregroundColor(.accentColor)
                            .monospaced()
                    } else {
                        Text("Run")
                            .font(.subheadline)
                            .bold()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .onTapGesture {
                                runRAM()
                            }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                
                // Flush DNS
                HStack {
                    VStack(alignment: .leading) {
                        Text("Flush DNS Cache")
                            .font(.headline)
                        Text("Resolves issues with websites not loading or network connection problems.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    
                    if isRunningDNS {
                        Text("[████░░░░]")
                            .foregroundColor(.accentColor)
                            .monospaced()
                    } else {
                        Text("Run")
                            .font(.subheadline)
                            .bold()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .onTapGesture {
                                runDNS()
                            }
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(30)
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
