import SwiftUI

/// The bar/panel background: real translucent glass that blurs the desktop and
/// tracks the system appearance (light material in light mode, dark in dark),
/// with a very subtle warm wash for our identity. Requires a non-opaque window
/// with a clear background (see PanelController). Falls back to a solid warm
/// surface under Reduce Transparency.
struct GlassSurface: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            Theme.barSolid
        } else {
            ZStack {
                // .behindWindow + .popover material adapts to light/dark and
                // blurs whatever is behind the window.
                VisualEffectView(material: Theme.panelMaterial, blendingMode: .behindWindow)
                Theme.barWarmTint.opacity(Theme.barWarmTintOpacity)
            }
        }
    }
}
