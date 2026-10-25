import Core
import Foundation

#if canImport(FoundationModels)
import FoundationModels

/// Apple Intelligence (Foundation Models) implementation of `ClipIntelligence`.
/// On-device, private, and free. Only compiled when the Foundation Models SDK is
/// present (macOS 26+ / Xcode 26+); gated at runtime on model availability.
@available(macOS 26.0, *)
public struct FoundationModelsIntelligence: ClipIntelligence {
    public init() {}

    public var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    @Generable
    struct Summary {
        @Guide(description: "A concise 2-5 word title")
        let title: String
        @Guide(description: "A single-sentence summary")
        let summary: String
    }

    public func summarize(_ text: String) async -> ClipSummary? {
        guard isAvailable else { return nil }
        let clipped = String(text.prefix(4000))
        let session = LanguageModelSession()
        guard let out = try? await session.respond(
            to: "Give a short title and one-sentence summary for this clipboard text:\n\(clipped)",
            generating: Summary.self
        ) else { return nil }
        let value = out.content
        return ClipSummary(title: value.title, summary: value.summary)
    }

    public func categorize(_ text: String, into collections: [String]) async -> String? {
        guard isAvailable, !collections.isEmpty else { return nil }
        let clipped = String(text.prefix(2000))
        let list = collections.joined(separator: ", ")
        let session = LanguageModelSession()
        guard let out = try? await session.respond(
            to: """
            Choose the single best-fitting category for this clipboard text from \
            this list: \(list). Reply with exactly one category name from the list.

            Text:
            \(clipped)
            """
        ) else { return nil }
        let answer = out.content.trimmingCharacters(in: .whitespacesAndNewlines)
        // Match case-insensitively back to a real collection name.
        return collections.first { $0.caseInsensitiveCompare(answer) == .orderedSame }
    }
}
#endif

/// Returns the best available on-device intelligence, else a no-op.
public enum ClipIntelligenceFactory {
    public static func make() -> ClipIntelligence {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = FoundationModelsIntelligence()
            if model.isAvailable { return model }
        }
        #endif
        return NoopClipIntelligence()
    }
}
