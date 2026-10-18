import SwiftUI

/// A Liquid-Glass halo drawn behind the selected card, tinted with its accent.
/// Uses `.glassEffect` on macOS 26+, falling back to a soft tinted fill.
struct SelectionHalo: View {
    let tint: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.cornerRadius + 4, style: Theme.cornerStyle)
        Group {
            if reduceTransparency {
                shape.fill(tint.opacity(0.35))
            } else {
                #if compiler(>=6.2)
                if #available(macOS 26.0, *) {
                    shape.fill(.clear)
                        .glassEffect(.regular.tint(tint.opacity(0.45)), in: shape)
                } else {
                    shape.fill(tint.opacity(0.25))
                }
                #else
                shape.fill(tint.opacity(0.25))
                #endif
            }
        }
    }
}
