import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private var statusItem: NSStatusItem!
    private let monitor = SystemMonitor()
    private let store = ProcessStore()
    private let popover = NSPopover()

    private var frames: [NSImage] = []
    private var framesKey = ""
    private var frameIndex = 0
    private var animTimer: Timer?
    private var listTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--render-preview"), i + 1 < args.count {
            renderPreview(to: args[i + 1])
            return
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let b = statusItem.button {
            b.target = self
            b.action = #selector(togglePopover(_:))
            b.imagePosition = .imageLeft
            b.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        }

        rebuildFramesIfNeeded()
        monitor.onUpdate = { [weak self] in self?.updateTitle() }
        monitor.start()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 380, height: 600)
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(monitor: monitor, store: store, quitSelf: { NSApp.terminate(nil) }))

        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
        nextFrame()

        if CommandLine.arguments.contains("--open") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.togglePopover(nil) }
        }
    }

    @objc private func defaultsChanged() {
        DispatchQueue.main.async {
            self.rebuildFramesIfNeeded()
            self.updateTitle()
        }
    }

    private func rebuildFramesIfNeeded() {
        let key = "\(Prefs.color.rawValue)-\(Prefs.accessory.rawValue)"
        guard key != framesKey else { return }
        framesKey = key
        frames = CatArt.menuBarFrames(color: Prefs.color, accessory: Prefs.accessory)
    }

    private func nextFrame() {
        if !frames.isEmpty {
            frameIndex = (frameIndex + 1) % frames.count
            statusItem.button?.image = frames[frameIndex]
        }
        let t = Timer(timeInterval: monitor.frameInterval(Prefs.speedSource), repeats: false) { [weak self] _ in
            self?.nextFrame()
        }
        RunLoop.main.add(t, forMode: .common)
        animTimer = t
    }

    private func updateTitle() {
        guard let b = statusItem.button else { return }
        let src = Prefs.speedSource
        b.title = Prefs.showPercent ? "\(Int(monitor.displayValue(src) * 100))%" : ""
        b.toolTip = "\(Prefs.catName): 메모리 \(Int(monitor.mem.ratio * 100))% · CPU \(Int(monitor.cpu * 100))%"
    }

    @objc private func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }
        guard let b = statusItem.button else { return }
        store.refresh()
        listTimer?.invalidate()
        let t = Timer(timeInterval: 2, repeats: true) { [weak self] _ in self?.store.refresh() }
        RunLoop.main.add(t, forMode: .common)
        listTimer = t

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: b.bounds, of: b, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        listTimer?.invalidate()
        listTimer = nil
    }

    // MARK: - 확인용: 화면을 PNG로 저장하고 종료

    private func renderPreview(to dir: String) {
        monitor.start()
        store.refresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.store.refresh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                for (tab, name) in [(MainTab.apps, "apps"), (.procs, "procs"), (.custom, "custom")] {
                    for dark in [false, true] {
                        let view = PopoverView(monitor: self.monitor, store: self.store, quitSelf: {}, startTab: tab)
                            .background(Color(nsColor: .windowBackgroundColor))
                        let host = NSHostingView(rootView: view)
                        host.frame = NSRect(x: 0, y: 0, width: 380, height: 600)
                        let win = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
                        win.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
                        win.contentView = host
                        win.setFrameOrigin(NSPoint(x: -4000, y: -4000))
                        win.orderFrontRegardless()
                        host.layoutSubtreeIfNeeded()
                        RunLoop.main.run(until: Date().addingTimeInterval(0.8))
                        if let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                            host.cacheDisplay(in: host.bounds, to: rep)
                            try? rep.representation(using: .png, properties: [:])?
                                .write(to: URL(fileURLWithPath: "\(dir)/popover-\(name)-\(dark ? "dark" : "light").png"))
                        }
                        win.orderOut(nil)
                    }
                }
                self.renderMenuBarStrip(to: "\(dir)/menubar-strip.png")
                exit(0)
            }
        }
    }

    private func renderMenuBarStrip(to path: String) {
        let combos: [(CatColor, Accessory)] = [(.auto, .none), (.cheese, .ribbon), (.gray, .crown), (.pink, .partyHat), (.sky, .scarf)]
        let p: CGFloat = 5
        let cw = CGFloat(CatArt.gridW) * p, ch = CGFloat(CatArt.gridH) * p
        let pad: CGFloat = 14
        let w = Int((cw + pad) * 4 + pad) * 2, h = Int((ch + pad) * CGFloat(combos.count) + pad)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        for (side, dark) in [false, true].enumerated() {
            let ox = CGFloat(side) * CGFloat(w / 2)
            (dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
            NSRect(x: ox, y: 0, width: CGFloat(w / 2), height: CGFloat(h)).fill()
            NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
                for (row, combo) in combos.enumerated() {
                    for f in 0..<CatArt.frameCount {
                        let img = CatArt.image(frame: f, color: combo.0, accessory: combo.1, pixel: p)
                        let x = ox + pad + CGFloat(f) * (cw + pad)
                        let y = CGFloat(h) - pad - ch - CGFloat(row) * (ch + pad)
                        img.draw(in: NSRect(x: x, y: y, width: cw, height: ch))
                    }
                }
            }
        }
        NSGraphicsContext.restoreGraphicsState()
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }
}
