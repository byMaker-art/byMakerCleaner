import Foundation
import Darwin

// MARK: - Data models

struct SystemMetrics {
    var cpuUsage: Double       = 0   // 0.0 – 1.0
    var ramUsed: Int64         = 0   // bytes
    var ramTotal: Int64        = 0   // bytes
    var diskUsed: Int64        = 0   // bytes
    var diskTotal: Int64       = 0   // bytes
    var netUpBytesPerSec: Int64   = 0
    var netDownBytesPerSec: Int64 = 0

    var cpuPercent: Int { Int(cpuUsage * 100) }
    var ramPercent: Double { ramTotal > 0 ? Double(ramUsed) / Double(ramTotal) : 0 }
    var diskPercent: Double { diskTotal > 0 ? Double(diskUsed) / Double(diskTotal) : 0 }
    var diskFree: Int64 { diskTotal - diskUsed }

    func formatted(bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    func formattedSpeed(_ bytesPerSec: Int64) -> String {
        if bytesPerSec < 1024 {
            return "\(bytesPerSec) B/s"
        } else if bytesPerSec < 1024 * 1024 {
            return String(format: "%.0f KB/s", Double(bytesPerSec) / 1024)
        } else {
            return String(format: "%.1f MB/s", Double(bytesPerSec) / (1024 * 1024))
        }
    }
}

// MARK: - SystemMetricsService

/// Polls system metrics every ~1 second using public macOS APIs.
/// Runs on a background thread; publishes updates on MainActor.
/// ТЗ п.0: интервал опроса 1–2 сек., фоновый процесс ~0% CPU в простое.
@MainActor
final class SystemMetricsService: ObservableObject {
    @Published var metrics = SystemMetrics()

    private var timer: Timer?

    // Network: store previous byte counts to compute delta
    private var prevNetUp: Int64 = 0
    private var prevNetDown: Int64 = 0
    private var prevNetTimestamp: Date = Date()

    // CPU: store previous ticks to compute delta
    private var prevCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) = (0, 0, 0, 0)

    init() {}

    func start() {
        guard timer == nil else { return }
        // Initial read to seed delta counters (no UI update yet)
        seedInitialCounters()
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Refresh

    private func refresh() {
        metrics.cpuUsage     = readCPU()
        (metrics.ramUsed, metrics.ramTotal) = readRAM()
        (metrics.diskUsed, metrics.diskTotal) = readDisk()
        (metrics.netUpBytesPerSec, metrics.netDownBytesPerSec) = readNet()
    }

    private func seedInitialCounters() {
        _ = readCPU()
        _ = readNet()
    }

    // MARK: - CPU  (host_processor_info — public Mach API)

    private func readCPU() -> Double {
        var cpuCount: natural_t = 0
        var cpuInfoArray: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &cpuInfoArray,
            &cpuInfoCount
        )
        guard kr == KERN_SUCCESS, let info = cpuInfoArray else { return metrics.cpuUsage }
        defer {
            let size = vm_size_t(cpuInfoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        var user: UInt64 = 0
        var system: UInt64 = 0
        var idle: UInt64 = 0
        var nice: UInt64 = 0

        for i in 0..<Int(cpuCount) {
            let base = Int32(CPU_STATE_MAX) * Int32(i)
            user   += UInt64(info[Int(base) + Int(CPU_STATE_USER)])
            system += UInt64(info[Int(base) + Int(CPU_STATE_SYSTEM)])
            idle   += UInt64(info[Int(base) + Int(CPU_STATE_IDLE)])
            nice   += UInt64(info[Int(base) + Int(CPU_STATE_NICE)])
        }

        let prev = prevCPUTicks
        let deltaUser   = user   - prev.user
        let deltaSys    = system - prev.system
        let deltaIdle   = idle   - prev.idle
        let deltaNice   = nice   - prev.nice
        let totalDelta  = deltaUser + deltaSys + deltaIdle + deltaNice

        prevCPUTicks = (user, system, idle, nice)

        guard totalDelta > 0 else { return metrics.cpuUsage }
        return Double(deltaUser + deltaSys + deltaNice) / Double(totalDelta)
    }

    // MARK: - RAM  (vm_statistics64 — public Mach API)

    private func readRAM() -> (used: Int64, total: Int64) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (metrics.ramUsed, metrics.ramTotal) }

        let pageSize = Int64(vm_kernel_page_size)
        let active   = Int64(stats.active_count)   * pageSize
        let wired    = Int64(stats.wire_count)      * pageSize
        let compressed = Int64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed

        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        return (max(0, min(used, total)), total)
    }

    // MARK: - Disk  (FileManager — public API)

    private func readDisk() -> (used: Int64, total: Int64) {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? Int64,
              let free  = attrs[.systemFreeSize] as? Int64
        else { return (metrics.diskUsed, metrics.diskTotal) }
        return (total - free, total)
    }

    // MARK: - Network  (getifaddrs — public POSIX API, delta per second)

    private func readNet() -> (upBps: Int64, downBps: Int64) {
        var totalUp: Int64 = 0
        var totalDown: Int64 = 0

        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let firstAddr = ifap else {
            return (metrics.netUpBytesPerSec, metrics.netDownBytesPerSec)
        }
        defer { freeifaddrs(ifap) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = cursor {
            let name = String(cString: addr.ifa_name)
            // Only count real interfaces: en (Ethernet/Wi-Fi), utun (VPN), awdl, bridge
            let isReal = name.hasPrefix("en") || name.hasPrefix("utun") || name.hasPrefix("bridge")
            if isReal, addr.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                if let data = addr.ifa_data?.assumingMemoryBound(to: if_data.self) {
                    totalUp   += Int64(data.pointee.ifi_obytes)
                    totalDown += Int64(data.pointee.ifi_ibytes)
                }
            }
            cursor = addr.ifa_next
        }

        let now = Date()
        let elapsed = now.timeIntervalSince(prevNetTimestamp)
        guard elapsed > 0.1 else { return (metrics.netUpBytesPerSec, metrics.netDownBytesPerSec) }

        let upBps   = max(0, Int64(Double(totalUp   - prevNetUp)   / elapsed))
        let downBps = max(0, Int64(Double(totalDown - prevNetDown) / elapsed))

        prevNetUp        = totalUp
        prevNetDown      = totalDown
        prevNetTimestamp = now

        // Clamp unrealistic spikes (>10 GB/s = counter wrap / interface reset)
        let cap: Int64 = 10 * 1024 * 1024 * 1024
        return (min(upBps, cap), min(downBps, cap))
    }
}
