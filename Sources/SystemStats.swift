import Foundation
import Darwin

struct MemorySnapshot {
    var used: UInt64 = 0
    var total: UInt64 = ProcessInfo.processInfo.physicalMemory
    var app: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var swapUsed: UInt64 = 0
    /// 1 = 여유, 2 = 주의, 4 = 위험 (macOS 메모리 압박 단계)
    var pressure: Int = 1

    var ratio: Double { total == 0 ? 0 : min(1, Double(used) / Double(total)) }
}

enum SystemStats {
    /// 활성 상태 보기의 "사용된 메모리"와 같은 계산: 앱 메모리 + 와이어드 + 압축
    static func memory() -> MemorySnapshot {
        var snap = MemorySnapshot()
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if kr == KERN_SUCCESS {
            let page = UInt64(vm_kernel_page_size)
            let internalPages = UInt64(stats.internal_page_count)
            let purgeable = UInt64(stats.purgeable_count)
            snap.app = (internalPages > purgeable ? internalPages - purgeable : 0) * page
            snap.wired = UInt64(stats.wire_count) * page
            snap.compressed = UInt64(stats.compressor_page_count) * page
            snap.used = min(snap.app + snap.wired + snap.compressed, snap.total)
        }

        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 {
            snap.swapUsed = swap.xsu_used
        }

        var level: Int32 = 0
        size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 {
            snap.pressure = Int(level)
        }
        return snap
    }
}

final class CPUSampler {
    private var prev: (UInt32, UInt32, UInt32, UInt32)?

    /// 0...1 전체 CPU 사용률 (직전 측정 이후)
    func sample() -> Double {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        let t = info.cpu_ticks
        let now = (t.0, t.1, t.2, t.3) // user, system, idle, nice
        defer { prev = now }
        guard let p = prev else { return 0 }
        let user = Double(now.0 &- p.0)
        let sys = Double(now.1 &- p.1)
        let idle = Double(now.2 &- p.2)
        let nice = Double(now.3 &- p.3)
        let busy = user + sys + nice
        let total = busy + idle
        return total > 0 ? busy / total : 0
    }
}

final class SystemMonitor: ObservableObject {
    @Published var mem = MemorySnapshot()
    @Published var cpu: Double = 0

    var onUpdate: (() -> Void)?
    private let cpuSampler = CPUSampler()
    private var timer: Timer?

    func start() {
        _ = cpuSampler.sample()
        tick()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        mem = SystemStats.memory()
        cpu = cpuSampler.sample()
        onUpdate?()
    }

    /// 0(한가함) ... 1(엄청 바쁨)
    func busyness(_ source: SpeedSource) -> Double {
        // 맥은 평소에도 메모리를 꽤 쓰므로 35%~95% 구간을 0~1로 펼친다
        var m = (mem.ratio - 0.35) / 0.60
        if mem.pressure >= 4 { m = 1 } else if mem.pressure >= 2 { m = max(m, 0.8) }
        m = min(1, max(0, m))
        let c = min(1, max(0, cpu))
        switch source {
        case .memory: return m
        case .cpu: return c
        case .busier: return max(m, c)
        }
    }

    /// 한 프레임 넘어가는 시간(초). 한가하면 0.25초, 바쁘면 0.04초
    func frameInterval(_ source: SpeedSource) -> Double {
        let b = busyness(source)
        return 0.25 - 0.21 * pow(b, 0.9)
    }

    func mood(_ source: SpeedSource) -> String {
        let b = busyness(source)
        if b < 0.33 { return "느긋하게 산책 중" }
        if b < 0.66 { return "열심히 달리는 중" }
        if b < 0.9 { return "전력으로 달리는 중!" }
        return "헥헥, 한계까지 달리는 중!!"
    }

    /// 메뉴바에 보여줄 숫자 (0...1)
    func displayValue(_ source: SpeedSource) -> Double {
        switch source {
        case .memory: return mem.ratio
        case .cpu: return cpu
        case .busier: return max(mem.ratio, cpu)
        }
    }
}
