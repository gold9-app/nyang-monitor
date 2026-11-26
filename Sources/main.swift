import AppKit

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--export-icon"), i + 1 < args.count {
    CatArt.exportIcon(to: args[i + 1])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // Dock에 안 뜨고 메뉴바에만
app.run()
