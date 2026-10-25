import XCTest
@testable import Core

/// In-memory pasteboard driven by tests.
final class MockPasteboard: PasteboardReading, @unchecked Sendable {
    private let lock = NSLock()
    private var _changeCount = 0
    private var _snapshot: PasteboardSnapshot?

    var changeCount: Int { lock.withLock { _changeCount } }
    func snapshot() -> PasteboardSnapshot? { lock.withLock { _snapshot } }

    /// Simulate a copy: bumps changeCount and sets contents.
    func put(
        _ reps: [CapturedRepresentation],
        source: String? = nil,
        concealed: Bool = false,
        transient: Bool = false
    ) {
        lock.withLock {
            _changeCount += 1
            _snapshot = PasteboardSnapshot(
                changeCount: _changeCount,
                representations: reps,
                sourceBundleID: source,
                isConcealed: concealed,
                isTransient: transient
            )
        }
    }
}

private func text(_ s: String, uti: String = UTIs.utf8PlainText) -> CapturedRepresentation {
    CapturedRepresentation(typeIdentifier: uti, data: Data(s.utf8))
}

final class ClassifierTests: XCTestCase {
    let classifier = Classifier()

    func testPlainText() {
        XCTAssertEqual(classifier.classify([text("hello world")]), .text)
    }

    func testURLBecomesLink() {
        XCTAssertEqual(classifier.classify([text("https://example.com")]), .link)
    }

    func testSpaceyStringIsNotLink() {
        XCTAssertEqual(classifier.classify([text("not a url https://x.com")]), .text)
    }

    func testImageWinsOverTextFallback() {
        let reps = [
            CapturedRepresentation(typeIdentifier: UTIs.png, data: Data([0x89, 0x50])),
            text("fallback"),
        ]
        XCTAssertEqual(classifier.classify(reps), .image)
    }

    func testAudioByUTI() {
        XCTAssertEqual(
            classifier.classify([CapturedRepresentation(typeIdentifier: "com.apple.m4a-audio", data: Data())]),
            .audio
        )
    }

    func testAudioByFileExtension() {
        let rep = CapturedRepresentation(typeIdentifier: UTIs.fileURL, data: Data("file:///Users/me/song.mp3".utf8))
        XCTAssertEqual(classifier.classify([rep]), .audio)
    }

    func testVideoByFileExtension() {
        let rep = CapturedRepresentation(typeIdentifier: UTIs.fileURL, data: Data("file:///m/clip.mov".utf8))
        XCTAssertEqual(classifier.classify([rep]), .video)
    }

    func testFileURLNonMediaIsFile() {
        let rep = CapturedRepresentation(typeIdentifier: UTIs.fileURL, data: Data("file:///Users/me/report.pdf".utf8))
        XCTAssertEqual(classifier.classify([rep]), .file)
    }

    func testMapLinkIsLinkAndDetected() {
        let urls = ["https://maps.apple.com/?ll=37.33,-122.03&q=Apple+Park",
                    "https://www.google.com/maps/@40.7,-74.0,15z",
                    "geo:37.33,-122.03"]
        for u in urls {
            XCTAssertEqual(classifier.classify([text(u)]), .link, u)
            XCTAssertTrue(MapLink.isMap(URL(string: u)), u)
        }
        XCTAssertFalse(MapLink.isMap(URL(string: "https://example.com")))
    }

    func testColor() {
        XCTAssertEqual(
            classifier.classify([CapturedRepresentation(typeIdentifier: UTIs.color, data: Data())]),
            .color
        )
    }

    func testRichTextAndHTML() {
        XCTAssertEqual(classifier.classify([CapturedRepresentation(typeIdentifier: UTIs.rtf, data: Data())]), .richText)
        XCTAssertEqual(classifier.classify([CapturedRepresentation(typeIdentifier: UTIs.html, data: Data())]), .html)
    }

    func testEmptyIsUnknown() {
        XCTAssertEqual(classifier.classify([]), .unknown)
    }

    func testCodeByHeuristics() {
        let snippet = "func greet(name: String) {\n    print(\"hi \\(name)\")\n}"
        XCTAssertEqual(classifier.classify([text(snippet)]), .code)
    }

    func testProseIsNotCode() {
        XCTAssertEqual(classifier.classify([text("Remember to buy milk and eggs today.")]), .text)
    }

    func testCodeFromDeveloperApp() {
        XCTAssertEqual(
            classifier.classify([text("let x = compute(y)")], sourceBundleID: "com.apple.dt.Xcode"),
            .code
        )
    }
}

final class FingerprintTests: XCTestCase {
    func testStableRegardlessOfOrder() {
        let a = text("a", uti: "public.a")
        let b = text("b", uti: "public.b")
        XCTAssertEqual(Fingerprint.make([a, b]), Fingerprint.make([b, a]))
    }

    func testDiffersByContent() {
        XCTAssertNotEqual(Fingerprint.make([text("one")]), Fingerprint.make([text("two")]))
    }
}

final class CaptureTests: XCTestCase {
    func testCapturesNewItem() async throws {
        let store = try PersistentStore.inMemory()
        let repo = CoreDataItemRepository(store: store)
        let pb = MockPasteboard()
        let capture = CaptureManager(pasteboard: pb, repository: repo)

        pb.put([text("first")])
        await capture.poll()

        let items = try await repo.recentItems(limit: 10, listID: nil)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items.first?.kind, .text)
        XCTAssertEqual(items.first?.plainText, "first")
    }

    func testDedupKeepsOneRow() async throws {
        let store = try PersistentStore.inMemory()
        let repo = CoreDataItemRepository(store: store)
        let pb = MockPasteboard()
        let capture = CaptureManager(pasteboard: pb, repository: repo)

        pb.put([text("same")])
        await capture.poll()
        pb.put([text("same")])
        await capture.poll()

        let items = try await repo.recentItems(limit: 10, listID: nil)
        XCTAssertEqual(items.count, 1)
    }

    func testCapturesImageAudioFile() async throws {
        let store = try PersistentStore.inMemory()
        let repo = CoreDataItemRepository(store: store)
        let pb = MockPasteboard()
        let capture = CaptureManager(pasteboard: pb, repository: repo)

        pb.put([CapturedRepresentation(typeIdentifier: UTIs.png, data: Data([0x89, 0x50, 0x4E, 0x47]))])
        await capture.poll()
        pb.put([CapturedRepresentation(typeIdentifier: UTIs.fileURL, data: Data("file:///x/track.m4a".utf8))])
        await capture.poll()
        pb.put([CapturedRepresentation(typeIdentifier: UTIs.fileURL, data: Data("file:///x/report.pdf".utf8))])
        await capture.poll()

        let items = try await repo.recentItems(limit: 10, listID: nil)
        let kinds = Set(items.map(\.kind))
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(kinds, [.image, .audio, .file])
    }

    func testAutoRouteDisabledKeepsHistory() {
        var rules = AutoCategorizationRules.defaults
        rules.enabled = false  // explicitly off
        XCTAssertEqual(rules.route(kind: .link, text: "https://x.com", fallback: CollectionSeed.historyID),
                       CollectionSeed.historyID)
    }

    func testDefaultsAreEnabledAndRouteEveryKind() {
        let rules = AutoCategorizationRules.defaults  // master ON by default
        XCTAssertTrue(rules.enabled)
        func id(_ name: String) -> UUID { CollectionSeed.starters.first { $0.name == name }!.id }
        XCTAssertEqual(rules.route(kind: .link, text: "https://x.com", fallback: CollectionSeed.historyID), id("Links"))
        XCTAssertEqual(rules.route(kind: .text, text: "hi", fallback: CollectionSeed.historyID), id("Notes"))
        XCTAssertEqual(rules.route(kind: .color, text: nil, fallback: CollectionSeed.historyID), id("Colors"))
        XCTAssertEqual(rules.route(kind: .video, text: nil, fallback: CollectionSeed.historyID), id("Media"))
    }

    func testAutoRouteEnabledKindRule() {
        var rules = AutoCategorizationRules.defaults
        rules.enabled = true
        rules.rules = rules.rules.map { var r = $0; r.enabled = true; return r }
        let links = CollectionSeed.starters.first { $0.name == "Links" }!.id
        let notes = CollectionSeed.starters.first { $0.name == "Notes" }!.id
        XCTAssertEqual(rules.route(kind: .link, text: "https://x.com", fallback: CollectionSeed.historyID), links)
        // Text now routes to Notes under the default rule set.
        XCTAssertEqual(rules.route(kind: .text, text: "hi", fallback: CollectionSeed.historyID), notes)
    }

    func testAutoRouteTextPattern() {
        let notes = CollectionSeed.starters.first { $0.name == "Notes" }!.id
        let rules = AutoCategorizationRules(enabled: true, rules: [
            AutoRule(enabled: true, match: .textPattern("github\\.com"), collectionID: notes),
        ])
        XCTAssertEqual(rules.route(kind: .link, text: "https://github.com/x", fallback: CollectionSeed.historyID), notes)
        XCTAssertEqual(rules.route(kind: .link, text: "https://apple.com", fallback: CollectionSeed.historyID), CollectionSeed.historyID)
    }

    func testSkipsConcealed() async throws {
        let store = try PersistentStore.inMemory()
        let repo = CoreDataItemRepository(store: store)
        let pb = MockPasteboard()
        let capture = CaptureManager(pasteboard: pb, repository: repo)

        pb.put([text("secret")], concealed: true)
        await capture.poll()

        let items = try await repo.recentItems(limit: 10, listID: nil)
        XCTAssertTrue(items.isEmpty)
    }

    func testSkipsIgnoredBundle() async throws {
        let store = try PersistentStore.inMemory()
        let repo = CoreDataItemRepository(store: store)
        let pb = MockPasteboard()
        let capture = CaptureManager(
            pasteboard: pb,
            repository: repo,
            config: CaptureConfig(ignoredBundleIDs: ["com.secret.app"])
        )

        pb.put([text("secret")], source: "com.secret.app")
        await capture.poll()

        let items = try await repo.recentItems(limit: 10, listID: nil)
        XCTAssertTrue(items.isEmpty)
    }
}

final class PlainTextTests: XCTestCase {
    func testStripKeepsOnlyPlainText() {
        let reps = [
            CapturedRepresentation(typeIdentifier: UTIs.rtf, data: Data([0x01])),
            CapturedRepresentation(typeIdentifier: UTIs.html, data: Data("<b>hi</b>".utf8)),
            text("hello world"),
        ]
        let stripped = PlainText.strip(reps)
        XCTAssertEqual(stripped.count, 1)
        XCTAssertEqual(stripped.first?.typeIdentifier, UTIs.utf8PlainText)
        XCTAssertEqual(stripped.first.flatMap { String(data: $0.data, encoding: .utf8) }, "hello world")
    }

    func testStripWithoutTextReturnsOriginal() {
        let reps = [CapturedRepresentation(typeIdentifier: UTIs.png, data: Data([0x89]))]
        XCTAssertEqual(PlainText.strip(reps), reps)
    }
}

final class ItemSearchTests: XCTestCase {
    private func item(kind: ClipKind = .image, text: String? = nil, ocr: String? = nil,
                      title: String? = nil) -> ClipItemModel {
        let reps = text.map { [CapturedRepresentation(typeIdentifier: UTIs.utf8PlainText, data: Data($0.utf8))] } ?? []
        return ClipItemModel(id: UUID(), kind: kind, createdAt: Date(), fingerprint: UUID().uuidString,
                             sourceBundleID: nil, listID: nil, representations: reps,
                             userTitle: title, ocrText: ocr)
    }

    func testOCRTextIsSearchable() {
        let screenshot = item(kind: .image, ocr: "Invoice #4821 total $99")
        XCTAssertTrue(ItemSearch.matches(screenshot, query: "invoice"))
        XCTAssertTrue(ItemSearch.matches(screenshot, query: "4821"))
        XCTAssertFalse(ItemSearch.matches(screenshot, query: "receipt"))
    }

    func testTitleAndTextSearchable() {
        XCTAssertTrue(ItemSearch.matches(item(text: "the quick brown fox"), query: "BROWN"))
        XCTAssertTrue(ItemSearch.matches(item(title: "My Snippet"), query: "snippet"))
    }

    func testFilterAndEmptyQuery() {
        let items = [item(ocr: "alpha"), item(ocr: "beta"), item(text: "alphabet")]
        XCTAssertEqual(ItemSearch.filter(items, query: "alpha").count, 2)
        XCTAssertEqual(ItemSearch.filter(items, query: "").count, 3)
    }
}

final class RetentionTests: XCTestCase {
    private func item(ago: TimeInterval, pinned: Bool = false, list: UUID? = nil) -> ClipItemModel {
        ClipItemModel(id: UUID(), kind: .text, createdAt: Date().addingTimeInterval(-ago),
                      fingerprint: UUID().uuidString, sourceBundleID: nil, listID: list,
                      representations: [], userTitle: nil, ocrText: nil, isPinned: pinned)
    }

    func testExpiry() {
        let cutoff = Date().addingTimeInterval(-7 * 86_400)
        XCTAssertTrue(Retention.isExpired(item(ago: 10 * 86_400), cutoff: cutoff))      // old history
        XCTAssertFalse(Retention.isExpired(item(ago: 1 * 86_400), cutoff: cutoff))      // recent
        XCTAssertFalse(Retention.isExpired(item(ago: 10 * 86_400, pinned: true), cutoff: cutoff))  // pinned exempt
        let pinboard = UUID()
        XCTAssertFalse(Retention.isExpired(item(ago: 10 * 86_400, list: pinboard), cutoff: cutoff)) // pinboard exempt
    }

    func testWindowCutoff() {
        XCTAssertNil(RetentionWindow.forever.cutoff())
        XCTAssertNotNil(RetentionWindow.month.cutoff())
    }
}

final class PinSortTests: XCTestCase {
    func testPinnedItemsSortToTop() async throws {
        let store = try PersistentStore.inMemory()
        let repo = CoreDataItemRepository(store: store)
        _ = try await repo.insert(ClipItemDraft.text("first"))
        let second = try await repo.insert(ClipItemDraft.text("second"))
        _ = try await repo.insert(ClipItemDraft.text("third"))   // newest

        try await repo.setPinned(itemID: second!.id, pinned: true)
        let items = try await repo.recentItems(limit: 10, listID: nil)
        XCTAssertEqual(items.first?.id, second?.id, "pinned item is first despite being older")
        XCTAssertTrue(items.first?.isPinned == true)
    }

    func testNewTextItemInserts() async throws {
        let store = try PersistentStore.inMemory()
        let repo = CoreDataItemRepository(store: store)
        let created = try await repo.insert(ClipItemDraft.text("hello from new item"))
        XCTAssertEqual(created?.kind, .text)
        XCTAssertEqual(created?.plainText, "hello from new item")
    }
}

final class PowerSearchTests: XCTestCase {
    private func make(_ kind: ClipKind, text: String? = nil, ocr: String? = nil,
                     app: String? = nil, ago: TimeInterval = 0) -> ClipItemModel {
        let reps = text.map { [CapturedRepresentation(typeIdentifier: UTIs.utf8PlainText, data: Data($0.utf8))] } ?? []
        return ClipItemModel(id: UUID(), kind: kind, createdAt: Date().addingTimeInterval(-ago),
                             fingerprint: UUID().uuidString, sourceBundleID: app, listID: nil,
                             representations: reps, userTitle: nil, ocrText: ocr)
    }

    func testTypoTolerance() {
        let items = [make(.link, text: "https://github.com/apple/swift")]
        XCTAssertEqual(PowerSearch.run(items, text: "githb", filters: SearchFilters()).count, 1)
        XCTAssertEqual(PowerSearch.run(items, text: "gtimhub", filters: SearchFilters()).count, 1)
        XCTAssertTrue(PowerSearch.run(items, text: "zzzz", filters: SearchFilters()).isEmpty)
    }

    func testKindAndAppFilters() {
        let items = [make(.link, text: "alpha", app: "com.apple.Safari"),
                     make(.image, ocr: "alpha", app: "com.apple.Photos")]
        XCTAssertEqual(PowerSearch.run(items, text: "alpha", filters: SearchFilters(kinds: [.image])).count, 1)
        XCTAssertEqual(PowerSearch.run(items, text: "", filters: SearchFilters(apps: ["com.apple.Safari"])).count, 1)
    }

    func testDateFilter() {
        let items = [make(.text, text: "x", ago: 0), make(.text, text: "x", ago: 10 * 86_400)]
        XCTAssertEqual(PowerSearch.run(items, text: "x", filters: SearchFilters(date: .last7Days)).count, 1)
        XCTAssertEqual(PowerSearch.run(items, text: "x", filters: SearchFilters(date: .any)).count, 2)
    }

    func testRankingPrefixBeatsFuzzyAndRecency() {
        let exact = make(.text, text: "swift playground", ago: 1000)
        let fuzzy = make(.text, text: "swfit notes", ago: 0)
        let result = PowerSearch.run([fuzzy, exact], text: "swift", filters: SearchFilters())
        XCTAssertEqual(result.first?.id, exact.id, "prefix match ranks above fuzzy")
    }
}

final class CaptureRulesTests: XCTestCase {
    func testCaptureRoutesByRuleWhenEnabled() async throws {
        let store = try PersistentStore.inMemory()
        let repo = CoreDataItemRepository(store: store)
        let pb = MockPasteboard()
        let capture = CaptureManager(pasteboard: pb, repository: repo)

        var rules = AutoCategorizationRules.defaults
        rules.enabled = true
        rules.rules = rules.rules.map { var r = $0; r.enabled = true; return r }
        await capture.setRules(rules)

        pb.put([CapturedRepresentation(typeIdentifier: UTIs.utf8PlainText, data: Data("https://example.com".utf8))])
        await capture.poll()

        let links = CollectionSeed.starters.first { $0.name == "Links" }!.id
        let items = try await repo.recentItems(limit: 10, listID: nil)
        XCTAssertEqual(items.first?.kind, .link)
        XCTAssertEqual(items.first?.listID, links, "link should be routed to Links")
    }
}
