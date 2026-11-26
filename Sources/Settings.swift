import AppKit

enum Keys {
    static let catName = "catName"
    static let catColor = "catColor"
    static let accessory = "accessory"
    static let speedSource = "speedSource"
    static let showPercent = "showPercent"
}

enum CatColor: String, CaseIterable, Identifiable {
    case auto, cheese, gray, cream, pink, mint, sky

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "기본"
        case .cheese: "치즈"
        case .gray: "회색"
        case .cream: "크림"
        case .pink: "분홍"
        case .mint: "민트"
        case .sky: "하늘"
        }
    }

    var nsColor: NSColor {
        switch self {
        case .auto: .labelColor
        case .cheese: NSColor(srgbRed: 0.96, green: 0.62, blue: 0.24, alpha: 1)
        case .gray: NSColor(srgbRed: 0.58, green: 0.60, blue: 0.64, alpha: 1)
        case .cream: NSColor(srgbRed: 0.93, green: 0.85, blue: 0.70, alpha: 1)
        case .pink: NSColor(srgbRed: 0.98, green: 0.55, blue: 0.70, alpha: 1)
        case .mint: NSColor(srgbRed: 0.40, green: 0.82, blue: 0.68, alpha: 1)
        case .sky: NSColor(srgbRed: 0.42, green: 0.68, blue: 0.98, alpha: 1)
        }
    }
}

enum Accessory: String, CaseIterable, Identifiable {
    case none, ribbon, crown, partyHat, scarf

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "없음"
        case .ribbon: "리본"
        case .crown: "왕관"
        case .partyHat: "고깔모자"
        case .scarf: "목도리"
        }
    }

    var color: NSColor {
        switch self {
        case .none: .clear
        case .ribbon: NSColor(srgbRed: 1.0, green: 0.36, blue: 0.62, alpha: 1)
        case .crown: NSColor(srgbRed: 1.0, green: 0.80, blue: 0.12, alpha: 1)
        case .partyHat: NSColor(srgbRed: 0.26, green: 0.62, blue: 1.0, alpha: 1)
        case .scarf: NSColor(srgbRed: 0.92, green: 0.22, blue: 0.22, alpha: 1)
        }
    }

    /// 고양이 그림 좌표(머리 기준). y가 음수면 머리 위 공간.
    var pixels: [(Int, Int)] {
        switch self {
        case .none: []
        case .ribbon: [(11, -1), (13, -1), (11, 0), (12, 0), (13, 0)]
        case .crown: [(10, -2), (12, -2), (14, -2), (10, -1), (11, -1), (12, -1), (13, -1), (14, -1)]
        case .partyHat: [(12, -2), (11, -1), (12, -1), (13, -1), (11, 0), (12, 0), (13, 0)]
        case .scarf: [(10, 3), (11, 3), (10, 4), (11, 4), (9, 5), (9, 6)]
        }
    }
}

enum SpeedSource: String, CaseIterable, Identifiable {
    case memory, cpu, busier

    var id: String { rawValue }

    var label: String {
        switch self {
        case .memory: "메모리"
        case .cpu: "CPU"
        case .busier: "더 바쁜 쪽"
        }
    }
}

enum Prefs {
    static var d: UserDefaults { .standard }
    static var color: CatColor { CatColor(rawValue: d.string(forKey: Keys.catColor) ?? "") ?? .auto }
    static var accessory: Accessory { Accessory(rawValue: d.string(forKey: Keys.accessory) ?? "") ?? .none }
    static var speedSource: SpeedSource { SpeedSource(rawValue: d.string(forKey: Keys.speedSource) ?? "") ?? .memory }
    static var showPercent: Bool { d.object(forKey: Keys.showPercent) as? Bool ?? true }
    static var catName: String { d.string(forKey: Keys.catName) ?? "나비" }
}
