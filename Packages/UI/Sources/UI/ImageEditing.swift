import AppKit

extension NSImage {
    /// PNG bytes for this image.
    var pngData: Data? {
        guard let tiff = tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    /// Returns a copy rotated clockwise by `degrees` (90 increments).
    func rotated(byDegrees degrees: CGFloat) -> NSImage {
        let radians = degrees * .pi / 180
        let swap = Int(degrees / 90) % 2 != 0
        let newSize = swap ? NSSize(width: size.height, height: size.width) : size
        let image = NSImage(size: newSize)
        image.lockFocus()
        let transform = NSAffineTransform()
        transform.translateX(by: newSize.width / 2, yBy: newSize.height / 2)
        transform.rotate(byRadians: -radians)   // clockwise
        transform.translateX(by: -size.width / 2, yBy: -size.height / 2)
        transform.concat()
        draw(at: .zero, from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        image.unlockFocus()
        return image
    }
}
