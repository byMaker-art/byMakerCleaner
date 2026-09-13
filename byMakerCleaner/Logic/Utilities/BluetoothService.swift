import Foundation
import IOBluetooth
import Combine

struct BluetoothDevice: Identifiable {
    let id = UUID()
    let name: String
    let isConnected: Bool
}

@MainActor
final class BluetoothService: ObservableObject {
    @Published var pairedDevices: [BluetoothDevice] = []
    
    private var timer: Timer?
    
    init() {
        start()
    }
    
    func start() {
        refresh()
        // Refresh every 5 seconds
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    private func refresh() {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else { return }
        
        pairedDevices = devices.map { device in
            BluetoothDevice(
                name: device.nameOrAddress ?? "Unknown",
                isConnected: device.isConnected()
            )
        }.sorted { $0.name < $1.name }
    }
}
