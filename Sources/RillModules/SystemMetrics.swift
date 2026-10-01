import Darwin
import Foundation

struct CPUTicks: Equatable, Sendable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    func utilization(since previous: CPUTicks) -> Double? {
        let busy = UInt64(user &- previous.user) + UInt64(system &- previous.system)
            + UInt64(nice &- previous.nice)
        let total = busy + UInt64(idle &- previous.idle)
        guard total > 0 else { return nil }
        return Double(busy) / Double(total)
    }
}

struct SystemMetricsSnapshot: Equatable, Sendable {
    let cpuUtilization: Double?
    let memoryUsedBytes: UInt64?
    let memoryTotalBytes: UInt64

    static let unavailable = SystemMetricsSnapshot(
        cpuUtilization: nil, memoryUsedBytes: nil, memoryTotalBytes: 0
    )

    var cpuPresentation: ModuleData {
        guard let utilization = cpuUtilization, utilization.isFinite,
              (0...1).contains(utilization) else {
            return .init(text: "CPU ?", tooltip: "CPU sample unavailable", health: .unavailable)
        }
        let percent = Int((utilization * 100).rounded())
        return .init(
            text: "CPU \(percent)%",
            tooltip: "CPU utilization across all cores: \(percent)%",
            state: utilization >= 0.9 ? .warning : .normal,
            value: utilization,
            popover: "CPU utilization: \(percent)%\nUser, system and nice time across all cores. Updated every 3 seconds."
        )
    }

    var memoryPresentation: ModuleData {
        guard let used = memoryUsedBytes, memoryTotalBytes > 0, used <= memoryTotalBytes else {
            return .init(text: "RAM ?", tooltip: "Memory sample unavailable", health: .unavailable)
        }
        let utilization = Double(used) / Double(memoryTotalBytes)
        let percent = Int((utilization * 100).rounded())
        let usedText = ByteCountFormatter.string(fromByteCount: Int64(clamping: used), countStyle: .memory)
        let totalText = ByteCountFormatter.string(fromByteCount: Int64(clamping: memoryTotalBytes), countStyle: .memory)
        return .init(
            text: "RAM \(percent)%",
            tooltip: "Active, wired and compressed memory: \(usedText) / \(totalText)",
            value: utilization,
            popover: "Active, wired and compressed memory: \(usedText)\nPhysical memory: \(totalText)\n\nThis excludes inactive and free pages. It is not macOS memory pressure or Activity Monitor's Memory Used. Updated every 3 seconds."
        )
    }
}

actor SystemMetricsSampler {
    private var previousCPU: CPUTicks?
    private var previousSampleTime: ContinuousClock.Instant?

    func sample(includeCPU: Bool, includeMemory: Bool) -> SystemMetricsSnapshot {
        let now = ContinuousClock.now
        let currentCPU = includeCPU ? readCPU() : nil
        let utilization: Double?
        if let currentCPU, let previousCPU, let previousSampleTime,
           previousSampleTime.duration(to: now) < .seconds(10) {
            utilization = currentCPU.utilization(since: previousCPU)
        } else {
            utilization = nil
        }
        previousCPU = currentCPU
        previousSampleTime = now
        return .init(
            cpuUtilization: utilization,
            memoryUsedBytes: includeMemory ? readMemory() : nil,
            memoryTotalBytes: ProcessInfo.processInfo.physicalMemory
        )
    }

    private func readCPU() -> CPUTicks? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info>.size / MemoryLayout<integer_t>.size)
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(host, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return .init(user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }

    private func readMemory() -> UInt64? {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        var pageSize: vm_size_t = 0
        let host = mach_host_self()
        defer { mach_port_deallocate(mach_task_self_, host) }
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(host, HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let pages = UInt64(info.active_count) + UInt64(info.wire_count) + UInt64(info.compressor_page_count)
        return pages * UInt64(pageSize)
    }
}
