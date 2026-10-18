import AppKit

// Agent app: no Dock icon (also set via LSUIElement in Info.plist). We build the
// NSApplication manually because this is a SwiftPM executable, not an Xcode app.
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate
app.run()
