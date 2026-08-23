import SwiftUI

struct LoginItemsView: View {
    @StateObject private var manager = LoginItemsManager()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Login Items")
                    .font(.title2).bold()
                Spacer()
                if manager.isScanning {
                    Text("Scanning...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
                Text("Refresh")
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .onTapGesture {
                        manager.scanAll()
                    }
            }
            .padding()
            
            Divider()
            
            if manager.items.isEmpty && !manager.isScanning {
                VStack {
                    Spacer()
                    Text("No items found.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
            } else {
                List {
                    // Apps Section
                    let apps = manager.items.filter { $0.type == .app }
                    if !apps.isEmpty {
                        Section(header: Text("Apps (Open at Login)").font(.headline)) {
                            ForEach(apps) { item in
                                itemRow(for: item)
                            }
                        }
                    }
                    
                    // User Agents Section
                    let userAgents = manager.items.filter { $0.type == .userAgent }
                    if !userAgents.isEmpty {
                        Section(header: Text("User Background Services").font(.headline)) {
                            ForEach(userAgents) { item in
                                itemRow(for: item)
                            }
                        }
                    }
                    
                    // System Daemons/Agents Section
                    let systemItems = manager.items.filter { $0.type == .systemAgent || $0.type == .systemDaemon }
                    if !systemItems.isEmpty {
                        Section(header: 
                            HStack {
                                Text("System Background Services").font(.headline)
                                Spacer()
                                Text("Open System Settings")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .onTapGesture {
                                        manager.openSystemSettingsLoginItems()
                                    }
                            }
                        ) {
                            ForEach(systemItems) { item in
                                itemRow(for: item)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            manager.scanAll()
        }
    }
    
    @ViewBuilder
    private func itemRow(for item: LoginItemModel) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .bold()
                Text(item.path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            if item.type == .app {
                Toggle("Hide", isOn: Binding(
                    get: { item.isHidden },
                    set: { _ in manager.toggleHiddenForApp(item) }
                ))
                .controlSize(.small)
                
                Text("Remove")
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .onTapGesture {
                        manager.removeApp(item)
                    }
            } else if item.type == .userAgent {
                Toggle("Enabled", isOn: Binding(
                    get: { item.isEnabled },
                    set: { _ in manager.toggleAgentEnabled(item) }
                ))
                .controlSize(.small)
            } else {
                Text("System / Read-Only")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
