import CryptoKit
import Foundation

/// Computes a stable SHA-256 fingerprint of a set of representations for dedup.
///
/// Representations are sorted by UTI so ordering differences don't change the
/// hash; each contributes its type identifier and raw bytes.
public enum Fingerprint {
    public static func make(_ reps: [CapturedRepresentation]) -> String {
        var hasher = SHA256()
        for rep in reps.sorted(by: { $0.typeIdentifier < $1.typeIdentifier }) {
            hasher.update(data: Data(rep.typeIdentifier.utf8))
            hasher.update(data: Data([0]))  // separator
            hasher.update(data: rep.data)
            hasher.update(data: Data([0]))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
