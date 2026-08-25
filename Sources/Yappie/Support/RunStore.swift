import Foundation
import Observation
import YappieActivity

/// Live-updating store of finished dictations, plus the activity figures derived from them.
///
/// The ledger is cached here rather than recomputed in the views. `ActivityLedger` walks a
/// 53-week window and every utterance to build it; the activity panel used to construct a
/// fresh one from each of its eight computed properties, and the main window's header chip
/// built a ninth on every redraw. Now it is built once per change to `runs`.
@MainActor
@Observable
final class RunStore {
    static let shared = RunStore()

    private(set) var runs: [DictationRun] = []
    private(set) var ledger = ActivityLedger(utterances: [])

    /// The calendar day the ledger was built for, so "today" can be rolled forward.
    private var ledgerDay: Date

    private init() {
        ledgerDay = Calendar.current.startOfDay(for: Date())
        reload()
    }

    func reload() {
        runs = RunLog.load()
        rebuildLedger()
    }

    /// Rebuilds the ledger if the calendar day has turned over since it was built.
    ///
    /// Without this, an app left open overnight keeps counting yesterday as today and the
    /// streak silently stops advancing. Called from the app delegate's one-second tick.
    func refreshLedgerIfDayChanged() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today != ledgerDay else { return }
        ledgerDay = today
        rebuildLedger()
    }

    private func rebuildLedger() {
        ledgerDay = Calendar.current.startOfDay(for: Date())
        ledger = ActivityLedger(utterances: runs.map(\.spoken))
    }

    // MARK: - Comparison groupings

    var comparisons: [[DictationRun]] {
        Dictionary(grouping: runs.filter { $0.group != nil }, by: { $0.group! })
            .values
            .sorted { ($0.first?.date ?? .distantPast) > ($1.first?.date ?? .distantPast) }
    }

    var singles: [DictationRun] {
        runs.filter { $0.group == nil }.reversed()
    }
}
