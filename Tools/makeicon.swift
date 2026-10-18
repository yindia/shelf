import AppKit

// Draws the Shelf app icon at a given pixel size: a warm gradient squircle with
// three stacked preview "cards", the front one with a colored header stripe.
func color(_ hex: String) -> NSColor {
    var s = hex; if s.hasPrefix("#") { s.removeFirst() }
    let v = UInt64(s, radix: 16)!
    return NSColor(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                   green: CGFloat((v >> 8) & 0xFF) / 255,
                   blue: CGFloat(v & 0xFF) / 255, alpha: 1)
}

func drawIcon(_ px: Int) -> Data {
    let s = CGFloat(px)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    let gc = NSGraphicsContext.current!

    // Background squircle with a deep blue→violet gradient.
    let inset = s * 0.055
    let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let radius = rect.width * 0.2237
    let bg = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    gc.saveGraphicsState()
    bg.addClip()
    NSGradient(colors: [color("#4E7CC4"), color("#6E57B0")])!.draw(in: rect, angle: -90)
    // soft top highlight
    NSGradient(colors: [NSColor(white: 1, alpha: 0.18), NSColor(white: 1, alpha: 0)])!
        .draw(in: rect, angle: -90)
    gc.restoreGraphicsState()

    // Three cards, back to front, with a slight fan.
    func card(cx: CGFloat, cy: CGFloat, w: CGFloat, h: CGFloat, rot: CGFloat, stripe: NSColor?) {
        gc.saveGraphicsState()
        let t = NSAffineTransform()
        t.translateX(by: cx, yBy: cy); t.rotate(byDegrees: rot); t.translateX(by: -cx, yBy: -cy)
        t.concat()
        let r = CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
        let cr = w * 0.14
        // shadow
        let sh = NSShadow(); sh.shadowColor = NSColor(white: 0, alpha: 0.28)
        sh.shadowBlurRadius = s * 0.02; sh.shadowOffset = NSSize(width: 0, height: -s * 0.012)
        sh.set()
        let path = NSBezierPath(roundedRect: r, xRadius: cr, yRadius: cr)
        NSColor.white.setFill(); path.fill()
        if let stripe {
            gc.saveGraphicsState()
            path.addClip()
            let band = CGRect(x: r.minX, y: r.maxY - h * 0.28, width: r.width, height: h * 0.28)
            stripe.setFill(); NSBezierPath(rect: band).fill()
            gc.restoreGraphicsState()
        }
        gc.restoreGraphicsState()
    }

    let cx = s / 2, cy = s / 2
    let w = s * 0.40, h = s * 0.52
    card(cx: cx - w * 0.34, cy: cy, w: w, h: h, rot: -10, stripe: color("#E7B61C"))
    card(cx: cx + w * 0.34, cy: cy, w: w, h: h, rot: 10, stripe: color("#2F8F6B"))
    card(cx: cx, cy: cy + s * 0.01, w: w, h: h, rot: 0, stripe: color("#D1485B"))

    image.unlockFocus()
    guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { return Data() }
    return png
}

// Build the iconset.
let fm = FileManager.default
let iconset = "build/AppIcon.iconset"
try? fm.removeItem(atPath: iconset)
try! fm.createDirectory(atPath: iconset, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    try! drawIcon(px).write(to: URL(fileURLWithPath: "\(iconset)/\(name).png"))
}
print("wrote \(iconset)")
