import Foundation

/// One finished dictation, stripped down to what the ledger needs.
///
/// Compare mode files several engine rows for the same recording, tagged with a shared
/// `group`. Collapsing those to one utterance is how a day of A/B testing doesn't look
/// like three times the words you actually spoke.
public struct SpokenUtterance: Equatable, Sendable {
    public var date: Date
    public var text: String
    /// Shared by every engine that processed the same recording. `nil` for ordinary runs.
    public var group: String?

    public init(date: Date, text: String, group: String? = nil) {
        self.date = date
        self.text = text
        self.group = group
    }

    /// One row per utterance. Grouped compare-mode rows keep the longest transcript —
    /// the audio is identical, so the wordiest engine is the closest count of what was said.
    public static func collapsingDuplicates(_ utterances: [SpokenUtterance]) -> [SpokenUtterance] {
        var ungrouped: [SpokenUtterance] = []
        var grouped: [String: [SpokenUtterance]] = [:]

        for utterance in utterances {
            if let group = utterance.group {
                grouped[group, default: []].append(utterance)
            } else {
                ungrouped.append(utterance)
            }
        }

        let representatives = grouped.values.map { members in
            members.max { a, b in
                let wordsA = SpokenWordCount.count(in: a.text)
                let wordsB = SpokenWordCount.count(in: b.text)
                if wordsA != wordsB { return wordsA < wordsB }
                return a.date < b.date
            }!
        }

        return ungrouped + representatives
    }
}
