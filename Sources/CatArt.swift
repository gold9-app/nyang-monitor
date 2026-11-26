import AppKit

/// 16x12 픽셀 고양이. 위 2줄은 모자 자리, 아래 1줄은 몸이 들썩이는 자리.
enum CatArt {
    static let gridW = 16
    static let gridH = 12
    static let top = 2
    static let frameCount = 4

    // 머리 + 몸통 (눈은 빈칸으로 뚫어서 배경이 비치게)
    private static let bodyRows = [
        "..........#...#.",
        "..........#####.",
        "..........###.#.",
        "...#############",
        "..############..",
        "..###########...",
    ]

    // 다리 4동작 (달리기 한 바퀴)
    private static let legRows: [[String]] = [
        [".##........##...",
         "##..........##..",
         "#............#.."],
        ["..##......##....",
         "..##.....##.....",
         "..#......#......"],
        ["....##..##......",
         ".....####.......",
         "....##..##......"],
        ["...##.....##....",
         "....##....##....",
         ".....#.....##..."],
    ]

    private static let tailUp = [(2, 3), (1, 2), (0, 1), (0, 0)]
    private static let tailFlat = [(2, 3), (1, 3), (0, 2), (0, 1)]
    private static let tails = [tailUp, tailUp, tailFlat, tailFlat]
    private static let bob = [0, 1, 1, 0]

    private static func parse(_ rows: [String], yOffset: Int) -> [(Int, Int)] {
        var out: [(Int, Int)] = []
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() where ch == "#" {
                out.append((x, y + yOffset))
            }
        }
        return out
    }

    private static let framePixels: [[(Int, Int)]] = (0..<frameCount).map { f in
        parse(bodyRows, yOffset: 0) + parse(legRows[f], yOffset: bodyRows.count) + tails[f]
    }

    static func image(frame: Int,
                      color: CatColor,
                      accessory: Accessory,
                      pixel p: CGFloat = 1.5,
                      template: Bool = false) -> NSImage {
        let f = ((frame % frameCount) + frameCount) % frameCount
        let size = NSSize(width: CGFloat(gridW) * p, height: CGFloat(gridH) * p)
        let img = NSImage(size: size, flipped: true) { _ in
            let oy = top + bob[f]
            let body = NSBezierPath()
            for (x, y) in framePixels[f] {
                body.appendRect(NSRect(x: CGFloat(x) * p, y: CGFloat(y + oy) * p, width: p, height: p))
            }
            (template ? NSColor.black : color.nsColor).setFill()
            body.fill()

            if !template, accessory != .none {
                let acc = NSBezierPath()
                for (x, y) in accessory.pixels {
                    acc.appendRect(NSRect(x: CGFloat(x) * p, y: CGFloat(y + oy) * p, width: p, height: p))
                }
                accessory.color.setFill()
                acc.fill()
            }
            return true
        }
        img.isTemplate = template
        return img
    }

    /// 메뉴바용 4프레임
    static func menuBarFrames(color: CatColor, accessory: Accessory) -> [NSImage] {
        let template = (color == .auto && accessory == .none)
        return (0..<frameCount).map { image(frame: $0, color: color, accessory: accessory, pixel: 1.5, template: template) }
    }

    /// 앱 아이콘(1024px PNG) 저장
    static func exportIcon(to path: String) {
        let side = 1024
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                                         bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                         colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        rep.size = NSSize(width: side, height: side)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

        let inset: CGFloat = 100
        let card = NSRect(x: inset, y: inset, width: CGFloat(side) - inset * 2, height: CGFloat(side) - inset * 2)
        let bg = NSBezierPath(roundedRect: card, xRadius: 185, yRadius: 185)
        NSGradient(starting: NSColor(srgbRed: 0.16, green: 0.22, blue: 0.38, alpha: 1),
                   ending: NSColor(srgbRed: 0.09, green: 0.12, blue: 0.22, alpha: 1))?.draw(in: bg, angle: -90)

        // 바닥 그래프 막대 (메모리 느낌)
        let bars: [CGFloat] = [0.35, 0.55, 0.45, 0.75, 0.6]
        let barW: CGFloat = 70
        for (i, h) in bars.enumerated() {
            let r = NSRect(x: card.minX + 110 + CGFloat(i) * 120, y: card.minY + 90, width: barW, height: 150 * h)
            NSColor(srgbRed: 0.40, green: 0.82, blue: 0.68, alpha: 0.35).setFill()
            NSBezierPath(roundedRect: r, xRadius: 14, yRadius: 14).fill()
        }

        let p: CGFloat = 40
        let catImg = image(frame: 0, color: .cheese, accessory: .none, pixel: p)
        let w = CGFloat(gridW) * p, h = CGFloat(gridH) * p
        catImg.draw(in: NSRect(x: (CGFloat(side) - w) / 2, y: card.minY + 200, width: w, height: h))

        NSGraphicsContext.restoreGraphicsState()
        if let data = rep.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }
}
