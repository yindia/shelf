import Core
import MapKit
import SwiftUI

/// Renders a static map image for a place via `MKMapSnapshotter`. Falls back to a
/// labeled placeholder when there's no coordinate or the snapshot is pending.
/// (Snapshotter is relatively heavy; this stays async and degrades gracefully.)
struct MapPreview: View {
    let place: MapLink.Place?
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(Theme.accent(for: .link).opacity(0.18))
                Image(systemName: "map.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent(for: .link))
            }
        }
        .task { await snapshot() }
    }

    private func snapshot() async {
        guard let place, place.hasCoordinate,
              let lat = place.latitude, let lng = place.longitude else { return }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        options.size = CGSize(width: Theme.cardWidth, height: 130)
        let snapshotter = MKMapSnapshotter(options: options)
        if let result = try? await snapshotter.start() {
            image = result.image
        }
    }
}
