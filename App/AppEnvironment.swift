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
    let quickLook: QuickLookPresenter
    /// On-device Apple Intelligence (Foundation Models) when available, else no-op.
    let intelligence: ClipIntelligence = ClipIntelligenceFactory.make()

    init() throws {
        let store = try PersistentStore.onDisk(
            name: "Shelf",
            cloudKitContainerID: SyncSettings.activeContainerID(PrivacyPersistence.load())
        )
        let repository = CoreDataItemRepository(store: store)
        let pasteboard = SystemPasteboard()

        self.store = store
        self.repository = repository
        self.pasteboard = pasteboard
        self.capture = CaptureManager(
            pasteboard: pasteboard,
            repository: repository,
            config: CaptureConfig(pollInterval: 0.3, ignoredBundleIDs: []),
            recognizer: VisionTextRecognizer()   // OCR for image search
        )
        self.pasteBack = PasteBack(pasteboard: pasteboard)
        self.thumbnailProvider = QuickLookThumbnailProvider()
        self.mediaInfoProvider = AVMediaInfoProvider()
        self.quickLook = QuickLookPresenter()
    }
}
