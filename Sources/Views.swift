import SwiftUI
import AppKit
import ServiceManagement

enum MainTab: String, CaseIterable { case apps = "앱", procs = "프로세스", custom = "꾸미기" }
enum SortKey: String, CaseIterable { case memory = "메모리순", cpu = "CPU순", name = "이름순" }

struct PopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @ObservedObject var store: ProcessStore
    var quitSelf: () -> Void

    @AppStorage(Keys.catName) private var catName = "나비"
    @AppStorage(Keys.catColor) private var colorRaw = CatColor.auto.rawValue
    @AppStorage(Keys.accessory) private var accRaw = Accessory.none.rawValue
    @AppStorage(Keys.speedSource) private var speedRaw = SpeedSource.memory.rawValue

    @State private var tab: MainTab
    @State private var sort: SortKey = .memory
    @State private var query = ""

    init(monitor: SystemMonitor, store: ProcessStore, quitSelf: @escaping () -> Void, startTab: MainTab = .apps) {
        self.monitor = monitor
        self.store = store
        self.quitSelf = quitSelf
        _tab = State(initialValue: startTab)
    }

    private var color: CatColor { CatColor(rawValue: colorRaw) ?? .auto }
    private var acc: Accessory { Accessory(rawValue: accRaw) ?? .none }
    private var source: SpeedSource { SpeedSource(rawValue: speedRaw) ?? .memory }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(monitor: monitor, name: catName, color: color, accessory: acc, source: source)
                .padding(14)

            Picker("", selection: $tab) {
                ForEach(MainTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 14)
            .padding(.bottom, 8)

            Group {
                switch tab {
                case .apps: listSection(store.apps)
                case .procs: listSection(store.processes)
                case .custom: CustomizeView()
                }
            }
            .frame(maxHeight: .infinity)

            Divider()
            HStack {
                Button("활성 상태 보기 열기") {
                    NSWorkspace.shared.openApplication(
                        at: URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app"),
                        configuration: NSWorkspace.OpenConfiguration())
                }
                .buttonStyle(.link)
                Spacer()
                Button("냥모니터 끄기", action: quitSelf)
                    .controlSize(.small)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(width: 380, height: 600)
    }

    private func sorted(_ items: [ProcItem]) -> [ProcItem] {
        var list = items
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty { list = list.filter { $0.name.lowercased().contains(q) } }
        switch sort {
        case .memory: list.sort { $0.memory > $1.memory }
        case .cpu: list.sort { $0.cpu > $1.cpu }
        case .name: list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return list
    }

    @ViewBuilder
    private func listSection(_ items: [ProcItem]) -> some View {
        let list = sorted(items)
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("찾기", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                Picker("", selection: $sort) {
                    ForEach(SortKey.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 96)
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 6)

            HStack {
                Text("이름 (\(list.count))")
                Spacer()
                Text("CPU").frame(width: 48, alignment: .trailing)
                Text("메모리").frame(width: 64, alignment: .trailing)
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)

            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(list) { item in
                        ProcRow(item: item,
                                icon: store.icons[item.id],
                                onQuit: { store.quit(item, force: false) },
                                onForce: { store.quit(item, force: true) })
                    }
                }
            }
            .scrollIndicators(.never)
        }
    }
}

// MARK: - 위쪽 고양이 + 게이지

struct HeaderView: View {
    @ObservedObject var monitor: SystemMonitor
    let name: String
    let color: CatColor
    let accessory: Accessory
    let source: SpeedSource

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                AnimatedCat(color: color, accessory: accessory, interval: monitor.frameInterval(source), pixel: 3)
                    .frame(width: 56, height: 42)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(name.isEmpty ? "고양이" : name)
                        .font(.system(size: 15, weight: .semibold))
                    Text(monitor.mood(source))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            UsageBar(title: "메모리",
                     detail: "\(Fmt.gb(monitor.mem.used)) / \(Fmt.gb(monitor.mem.total)) GB  ·  \(Int(monitor.mem.ratio * 100))%",
                     ratio: monitor.mem.ratio,
                     color: pressureColor)
            UsageBar(title: "CPU",
                     detail: "\(Int(monitor.cpu * 100))%",
                     ratio: monitor.cpu,
                     color: monitor.cpu > 0.8 ? .red : (monitor.cpu > 0.5 ? .orange : .green))

            HStack {
                Text("메모리 상태: \(pressureText)")
                Spacer()
                Text("스왑 \(Fmt.bytes(monitor.mem.swapUsed))")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
    }

    private var pressureColor: Color {
        switch monitor.mem.pressure {
        case 4...: .red
        case 2...: .orange
        default: .green
        }
    }

    private var pressureText: String {
        switch monitor.mem.pressure {
        case 4...: "위험"
        case 2...: "주의"
        default: "여유"
        }
    }
}

struct UsageBar: View {
    let title: String
    let detail: String
    let ratio: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(detail).font(.system(size: 12)).monospacedDigit().foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule().fill(color)
                        .frame(width: max(4, geo.size.width * min(1, max(0, ratio))))
                        .animation(.easeOut(duration: 0.4), value: ratio)
                }
            }
            .frame(height: 7)
        }
    }
}

struct AnimatedCat: View {
    let color: CatColor
    let accessory: Accessory
    let interval: Double
    let pixel: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: interval)) { ctx in
            let f = Int(ctx.date.timeIntervalSinceReferenceDate / interval) % CatArt.frameCount
            Image(nsImage: CatArt.image(frame: f, color: color, accessory: accessory, pixel: pixel))
        }
    }
}

// MARK: - 목록 한 줄

struct ProcRow: View {
    let item: ProcItem
    let icon: NSImage?
    let onQuit: () -> Void
    let onForce: () -> Void

    @State private var hover = false
    @State private var armed = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if let icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "gearshape").foregroundStyle(.secondary)
                }
            }
            .frame(width: 18, height: 18)

            Text(item.name)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 6)

            if hover {
                Button("종료", action: onQuit)
                    .controlSize(.small)
                Button(armed ? "한 번 더!" : "강제 종료") {
                    if armed {
                        armed = false
                        onForce()
                    } else {
                        armed = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { armed = false }
                    }
                }
                .controlSize(.small)
                .foregroundColor(.red)
            } else {
                Text(String(format: "%.1f%%", item.cpu))
                    .frame(width: 48, alignment: .trailing)
                    .foregroundStyle(.secondary)
                Text(Fmt.bytes(item.memory))
                    .frame(width: 64, alignment: .trailing)
            }
        }
        .font(.system(size: 12))
        .monospacedDigit()
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(hover ? Color.primary.opacity(0.07) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hover = $0; if !$0 { armed = false } }
    }
}

// MARK: - 꾸미기

struct CustomizeView: View {
    @AppStorage(Keys.catName) private var catName = "나비"
    @AppStorage(Keys.catColor) private var colorRaw = CatColor.auto.rawValue
    @AppStorage(Keys.accessory) private var accRaw = Accessory.none.rawValue
    @AppStorage(Keys.speedSource) private var speedRaw = SpeedSource.memory.rawValue
    @AppStorage(Keys.showPercent) private var showPercent = true

    @State private var loginOn = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private var color: CatColor { CatColor(rawValue: colorRaw) ?? .auto }
    private var acc: Accessory { Accessory(rawValue: accRaw) ?? .none }
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Block("이름") {
                    TextField("고양이 이름", text: $catName)
                        .textFieldStyle(.roundedBorder)
                }

                Block("털 색") {
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(CatColor.allCases) { c in
                            Choice(image: CatArt.image(frame: 0, color: c, accessory: acc, pixel: 2.5),
                                   label: c.label,
                                   selected: color == c) { colorRaw = c.rawValue }
                        }
                    }
                }

                Block("꾸미기") {
                    LazyVGrid(columns: cols, spacing: 8) {
                        ForEach(Accessory.allCases) { a in
                            Choice(image: CatArt.image(frame: 0, color: color, accessory: a, pixel: 2.5),
                                   label: a.label,
                                   selected: acc == a) { accRaw = a.rawValue }
                        }
                    }
                }

                Block("무엇을 보고 달릴까") {
                    Picker("", selection: $speedRaw) {
                        ForEach(SpeedSource.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("메뉴바에 숫자 보이기", isOn: $showPercent)
                    Toggle("맥 켤 때 자동으로 시작", isOn: Binding(get: { loginOn }, set: setLogin))
                    if let loginError {
                        Text(loginError).font(.system(size: 11)).foregroundStyle(.red)
                    }
                }
                .font(.system(size: 12))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    private func setLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "설정 못 했어요: \(error.localizedDescription)"
        }
        loginOn = SMAppService.mainApp.status == .enabled
    }
}

struct Block<Content: View>: View {
    let title: String
    let content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 12, weight: .semibold))
            content
        }
    }
}

struct Choice: View {
    let image: NSImage
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(nsImage: image)
                    .frame(height: 32)
                Text(label).font(.system(size: 11))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
