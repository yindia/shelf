import Foundation
import NaturalLanguage

/// Ranks clips by on-device sentence-embedding similarity to a query. Used as a
/// fallback when lexical Power Search finds nothing — "no exact match, here's the
/// closest in meaning". Embeddings are cached in memory per text.
public final class SemanticRanker: @unchecked Sendable {
    private let embedding: NLEmbedding?
    private var cache: [String: [Double]] = [:]
    private let lock = NSLock()

    public init(language: NLLanguage = .english) {
        self.embedding = NLEmbedding.sentenceEmbedding(for: language)
    }

    public var isAvailable: Bool { embedding != nil }

    /// Items most similar in meaning to `query`, best first. Returns `items`
    /// unchanged when embeddings are unavailable.
    public func rank(
        _ items: [ClipItemModel],
        query: String,
        limit: Int = 50
    ) -> [ClipItemModel] {
        guard let q = vector(query) else { return items }
        let scored = items.prefix(300).compactMap { item -> (ClipItemModel, Double)? in
            guard let v = vector(text(for: item)) else { return nil }
            return (item, cosine(q, v))
        }
        return scored
            .filter { $0.1 > 0.2 }                 // drop weak matches
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    private func text(for item: ClipItemModel) -> String {
        [item.userTitle, item.plainText, item.ocrText]
            .compactMap { $0 }.joined(separator: " ")
    }

    private func vector(_ text: String) -> [Double]? {
        guard let embedding else { return nil }
        let key = String(text.prefix(500)).lowercased()
        guard !key.isEmpty else { return nil }
        if let hit = lock.withLock({ cache[key] }) { return hit }
        guard let v = embedding.vector(for: key) else { return nil }
        lock.withLock { cache[key] = v }
        return v
    }

    private func cosine(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return 0 }
        var dot = 0.0, na = 0.0, nb = 0.0
        for i in a.indices {
            dot += a[i] * b[i]; na += a[i] * a[i]; nb += b[i] * b[i]
        }
        guard na > 0, nb > 0 else { return 0 }
        return dot / (na.squareRoot() * nb.squareRoot())
    }
}
