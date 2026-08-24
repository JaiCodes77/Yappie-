import Foundation

/// How many words a transcript contains.
///
/// This is the unit the activity ledger counts. ICU word breaks via
/// `enumerateSubstrings(.byWords)` — not a `\b` regex — so punctuation-only strings
/// contribute nothing and CJK dictation still produces a count. NFC first, because
/// macOS speech engines often return decomposed accented letters.
public enum SpokenWordCount: Sendable {
    public static func count(in text: String) -> Int {
        let normalized = text.precomposedStringWithCanonicalMapping
        guard !normalized.isEmpty else { return 0 }
        var total = 0
        normalized.enumerateSubstrings(
            in: normalized.startIndex...,
            options: .byWords
        ) { substring, _, _, _ in
            if substring != nil { total += 1 }
        }
        return total
    }
}
