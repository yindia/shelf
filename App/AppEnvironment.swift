import Core
import Foundation
import Platform

/// Composition root. Builds and owns the app's stateful services and wires their
/// dependencies explicitly — no global singletons. Swap pieces here for tests/mocks.
@MainActor
final class AppEnvironment {
    let store: PersistentStore
    let repository: CoreDataItemRepository
    let pasteboard: SystemPasteboard
    let capture: CaptureManager
    let pasteBack: PasteBack
    let thumbnailProvider: QuickLookThumbnailProvider
    let mediaInfoProvider: AVMediaInfoProvider

    init() throws {
        let store = try PersistentStore.onDisk(name: "Shelf")
        let repository = CoreDataItemRepository(store: store)
        let pasteboard = SystemPasteboard()

        self.store = store
        self.repository = repository
        self.pasteboard = pasteboard
        self.capture = CaptureManager(
            pasteboard: pasteboard,
            repository: repository,
            config: CaptureConfig(pollInterval: 0.3, ignoredBundleIDs: [])
        )
        self.pasteBack = PasteBack(pasteboard: pasteboard)
        self.thumbnailProvider = QuickLookThumbnailProvider()
        self.mediaInfoProvider = AVMediaInfoProvider()
    }
}
