import SwiftUI

/// Draws a simple bar waveform from normalized amplitudes (0...1). Inherits the
/// current `foregroundStyle`.
struct WaveformView: View {
    let bars: [Float]

    /// A gentle placeholder pattern used until real samples arrive.
    static let placeholder: [Float] = (0..<40).map { i in
        0.25 + 0.6 * Float(abs(sin(Double(i) / 3.0)))
    }

    var body: some View {
        GeometryReader { geo in
            let count = max(bars.count, 1)
            let spacing: CGFloat = 2
            let barWidth = max(1, (geo.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, amplitude in
                    Capsule()
                        .frame(width: barWidth,
                               height: max(2, geo.size.height * CGFloat(amplitude)))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
        }
    }
}
