import AppKit
import Darwin

struct ProcItem: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let path: String
    let memory: UInt64
    let cpu: Double
    let isApp: Bool
}

final class ProcessStore: ObservableObject {
    @Published var apps: [ProcItem] = []
    @Published var processes: [ProcItem] = []
    var icons: [pid_t: NSImage] = [:]

    private let queue = DispatchQueue(label: "nyang.process")
    private var lastCPU: [pid_t: UInt64] = [:]
    private var lastTime: UInt64 = 0
    private let timebase: (UInt64, UInt64) = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return (UInt64(tb.numer), UInt64(max(tb.denom, 1)))
    }()

    func refresh() {
        let running = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
        var iconMap: [pid_t: NSImage] = [:]
        var metas: [(pid: pid_t, name: String, bundle: String?)] = []
        for a in running {
            if let icon = a.icon { iconMap[a.processIdentifier] = icon }
            metas.append((a.processIdentifier, a.localizedName ?? "앱", a.bundleURL?.path))
        }

        queue.async { [weak self] in
            guard let self else { return }
            let now = DispatchTime.now().uptimeNanoseconds
            let elapsed = self.lastTime == 0 ? 0 : now - self.lastTime
            var procs: [ProcItem] = []
            var newCPU: [pid_t: UInt64] = [:]

            for pid in Self.allPIDs() where pid > 0 {
                guard let ru = Self.rusage(pid) else { continue } // 내 계정 프로세스만 읽힘
                let cpuNs = (ru.ri_user_time + ru.ri_system_time) * self.timebase.0 / self.timebase.1
                newCPU[pid] = cpuNs
                var cpu = 0.0
                if elapsed > 0, let prev = self.lastCPU[pid], cpuNs >= prev {
                    cpu = Double(cpuNs - prev) / Double(elapsed) * 100
                }
                let path = Self.path(pid)
                let name = path.isEmpty ? Self.name(pid) : (path as NSString).lastPathComponent
                procs.append(ProcItem(id: pid, name: name, path: path, memory: ru.ri_phys_footprint, cpu: cpu, isApp: false))
            }
            self.lastCPU = newCPU
            self.lastTime = now

            // 앱 = 본체 + 앱 안에 들어있는 도우미 프로세스(크롬 렌더러 등) 합계
            var appItems: [ProcItem] = []
            for m in metas {
                let prefix = m.bundle.map { $0 + "/" }
                var mem: UInt64 = 0
                var cpu = 0.0
                for p in procs where p.id == m.pid || (prefix != nil && p.path.hasPrefix(prefix!)) {
                    mem += p.memory
                    cpu += p.cpu
                }
                appItems.append(ProcItem(id: m.pid, name: m.name, path: m.bundle ?? "", memory: mem, cpu: cpu, isApp: true))
            }

            DispatchQueue.main.async {
                self.icons = iconMap
                self.apps = appItems
                self.processes = procs
            }
        }
    }

    func quit(_ item: ProcItem, force: Bool) {
        if item.isApp, let app = NSRunningApplication(processIdentifier: item.id) {
            if force { app.forceTerminate() } else { app.terminate() }
        } else {
            kill(item.id, force ? SIGKILL : SIGTERM)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in self?.refresh() }
    }

    // MARK: - libproc 도우미

    private static func allPIDs() -> [pid_t] {
        let n = proc_listallpids(nil, 0)
        guard n > 0 else { return [] }
        var buf = [pid_t](repeating: 0, count: Int(n) + 64)
        let got = proc_listallpids(&buf, Int32(buf.count * MemoryLayout<pid_t>.size))
        return Array(buf.prefix(max(0, Int(got))))
    }

    private static func rusage(_ pid: pid_t) -> rusage_info_v4? {
        var info = rusage_info_v4()
        let r = withUnsafeMutablePointer(to: &info) { ptr -> Int32 in
            ptr.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_V4, $0)
            }
        }
        return r == 0 ? info : nil
    }

    private static func path(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 4096)
        let len = proc_pidpath(pid, &buf, UInt32(buf.count))
        return len > 0 ? String(cString: buf) : ""
    }

    private static func name(_ pid: pid_t) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        proc_name(pid, &buf, UInt32(buf.count))
        let s = String(cString: buf)
        return s.isEmpty ? "pid \(pid)" : s
    }
}

enum Fmt {
    static func bytes(_ b: UInt64) -> String {
        let gb = Double(b) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(b) / 1_048_576
        return String(format: "%.0f MB", mb)
    }

    static func gb(_ b: UInt64) -> String {
        String(format: "%.1f", Double(b) / 1_073_741_824)
    }
}
