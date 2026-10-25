import Foundation

/// Tunable capture behaviour.
public struct CaptureConfig: Sendable {
    /// Pasteboard poll interval in seconds.
    public var pollInterval: TimeInterval
    /// Bundle ids whose copies are never captured (e.g. password managers).
    public var ignoredBundleIDs: Set<String>
    /// Collection new captures are filed into (the default history collection).
    public var defaultListID: UUID
    /// Skip content marked confidential (nspasteboard concealed type).
    public var ignoreConfidential: Bool

    public init(
        pollInterval: TimeInterval = 0.3,
        ignoredBundleIDs: Set<String> = [],
        defaultListID: UUID = CollectionSeed.historyID,
        ignoreConfidential: Bool = true
    ) {
        self.pollInterval = pollInterval
        self.ignoredBundleIDs = ignoredBundleIDs
        self.defaultListID = defaultListID
        self.ignoreConfidential = ignoreConfidential
    }
}

/// Polls the pasteboard, classifies and dedups changes, and writes new items.
///
/// An `actor` so its `lastChangeCount` is isolated. The timer runs on a private
/// queue and hops into the actor on each tick.
public actor CaptureManager {
    private let pasteboard: PasteboardReading
    private let repository: ItemRepositoryWriting
    private let classifier: Classifier
    private var config: CaptureConfig
    /// Optional OCR engine; when set, image captures are indexed for search.
    private let recognizer: TextRecognizing?

    private var timer: DispatchSourceTimer?
    private var lastChangeCount: Int
    private var paused = false
    /// Opt-in auto-filing rules (default OFF → everything lands in history).
    private var rules: AutoCategorizationRules = AutoCategorizationRules()
    /// Fingerprints we wrote ourselves (paste-back) so we skip re-capturing them.
    private var suppressedFingerprints: Set<String> = []
    /// Notified after each new item is persisted (e.g. to push onto Paste Stack).
    private var onNewItem: (@Sendable (ClipItemModel) -> Void)?
    /// On-device intelligence used to categorize ambiguous text (no-op by default).
    private var intelligence: ClipIntelligence = NoopClipIntelligence()
    /// Non-default collections the AI may route into: display name → id.
    private var aiCollections: [(name: String, id: UUID)] = []

    public init(
        pasteboard: PasteboardReading,
        repository: ItemRepositoryWriting,
        classifier: Classifier = Classifier(),
        config: CaptureConfig = CaptureConfig(),
        recognizer: TextRecognizing? = nil
    ) {
        self.pasteboard = pasteboard
        self.repository = repository
        self.classifier = classifier
        self.config = config
        self.recognizer = recognizer
        self.lastChangeCount = pasteboard.changeCount
    }

    public func start() {
        guard timer == nil else { return }
        let queue = DispatchQueue(label: "com.yindia.shelf.capture")
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + config.pollInterval, repeating: config.pollInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.poll() }
        }
        self.timer = timer
        timer.resume()
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    /// Pause/resume collecting without tearing down the timer.
    public func setPaused(_ value: Bool) {
        paused = value
        // Avoid capturing everything copied while paused once we resume.
        if !value { lastChangeCount = pasteboard.changeCount }
    }
    public var isPaused: Bool { paused }

    /// Tell the capturer to ignore the next appearance of this fingerprint
    /// (used when we restore an item to the pasteboard during paste-back).
    public func suppress(fingerprint: String) {
        suppressedFingerprints.insert(fingerprint)
    }

    /// Updates the auto-categorization rules (from settings).
    public func setRules(_ rules: AutoCategorizationRules) {
        self.rules = rules
    }

    /// Register a sink for newly captured items (Paste Stack pushes here).
    public func setOnNewItem(_ handler: (@Sendable (ClipItemModel) -> Void)?) {
        self.onNewItem = handler
    }

    /// Provide on-device intelligence + the collections it may route text into.
    public func setIntelligence(_ intelligence: ClipIntelligence, collections: [(name: String, id: UUID)]) {
        self.intelligence = intelligence
        self.aiCollections = collections
    }

    /// Toggle whether confidential (concealed) content is ignored.
    public func setIgnoreConfidential(_ value: Bool) {
        config.ignoreConfidential = value
    }

    /// Apps whose copies are never captured (per-app exclusions from settings).
    public func setIgnoredBundleIDs(_ ids: Set<String>) {
        config.ignoredBundleIDs = ids
    }

    /// Reads the pasteboard once and persists a new item if warranted.
    /// Exposed `internal` for deterministic testing without the timer.
    func poll() async {
        guard !paused else { return }
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let snapshot = pasteboard.snapshot() else { return }
        guard !snapshot.isTransient else { return }
        if config.ignoreConfidential, snapshot.isConcealed { return }
        if let bundleID = snapshot.sourceBundleID, config.ignoredBundleIDs.contains(bundleID) {
            return
        }

        let reps = snapshot.representations.filter { !isControlType($0.typeIdentifier) }
        guard !reps.isEmpty else { return }

        let fingerprint = Fingerprint.make(reps)
        if suppressedFingerprints.remove(fingerprint) != nil { return }

        let kind = classifier.classify(reps, sourceBundleID: snapshot.sourceBundleID)
        let text = reps.first { $0.typeIdentifier == UTIs.utf8PlainText || $0.typeIdentifier == UTIs.plainText }
            .flatMap { String(data: $0.data, encoding: .utf8) }
        // OCR image captures so screenshots are findable in search.
        var ocrText: String?
        if kind == .image, let recognizer {
            let imageData = reps.first { $0.typeIdentifier == UTIs.png || $0.typeIdentifier == UTIs.tiff }?.data
            if let imageData { ocrText = await recognizer.recognizeText(in: imageData) }
        }
        var listID = rules.route(kind: kind, text: text, fallback: config.defaultListID)
        // When a text clip would land in the catch-all history, let on-device
        // intelligence pick a better collection (no-op unless available).
        if listID == config.defaultListID, intelligence.isAvailable, !aiCollections.isEmpty,
           [.text, .richText, .html].contains(kind), let text, text.count >= 40,
           let name = await intelligence.categorize(text, into: aiCollections.map(\.name)),
           let match = aiCollections.first(where: { $0.name == name }) {
            listID = match.id
        }
        let draft = ClipItemDraft(
            kind: kind,
            fingerprint: fingerprint,
            representations: reps,
            sourceBundleID: snapshot.sourceBundleID,
            listID: listID,
            ocrText: ocrText
        )
        if let inserted = try? await repository.insert(draft) {
            onNewItem?(inserted)
        }
    }

    private func isControlType(_ uti: String) -> Bool {
        uti == UTIs.concealed || uti == UTIs.transient || uti == UTIs.autogenerated || uti == UTIs.source
    }
}
