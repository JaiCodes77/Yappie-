import SwiftUI

/// Live-updating store behind the comparison window.
@MainActor
@Observable
final class RunStore {
    static let shared = RunStore()

    private(set) var runs: [DictationRun] = []

    private init() { reload() }

    func reload() {
        runs = RunLog.load()
    }

    var comparisons: [[DictationRun]] {
        Dictionary(grouping: runs.filter { $0.group != nil }, by: { $0.group! })
            .values
            .sorted { ($0.first?.date ?? .distantPast) > ($1.first?.date ?? .distantPast) }
    }

    var singles: [DictationRun] {
        runs.filter { $0.group == nil }.reversed()
    }
}

struct ComparisonWindow: View {
    @Bindable var controller: DictationController
    @State private var store = RunStore.shared
    @State private var settings = Settings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.roomy) {
                header
                recordBar

                if store.runs.isEmpty {
                    emptyState
                } else {
                    ForEach(Array(store.comparisons.enumerated()), id: \.offset) { _, group in
                        ComparisonCard(runs: group)
                    }
                    ForEach(Array(store.singles.enumerated()), id: \.offset) { _, run in
                        SingleCard(run: run)
                    }
                }
            }
            .padding(DS.Space.wide)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: DS.Size.comparisonMinWidth, minHeight: DS.Size.comparisonMinHeight)
        .background(DS.Color.chassis)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: DS.Space.tight) {
                Silkscreen(text: "Engine comparison", large: true, color: DS.Color.ink)
                Text("\(store.runs.count) recording\(store.runs.count == 1 ? "" : "s")")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkSecondary)
            }
            Spacer()
            if !store.runs.isEmpty {
                TransportKey(title: "Clear", engagedColor: DS.Color.copper) {
                    RunLog.clear()
                    store.reload()
                }
            }
        }
    }

    private var recordBar: some View {
        let isRecording = controller.state.isActive

        return VStack(alignment: .leading, spacing: DS.Space.snug) {
            TransportKey(
                title: isRecording ? "Stop" : "Record all three",
                systemImage: isRecording ? "stop.fill" : "circle.fill",
                isEngaged: isRecording
            ) {
                if isRecording {
                    controller.stopButtonRecording()
                } else {
                    controller.startButtonRecording()
                }
            }

            Text(statusLine(isRecording: isRecording))
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.inkSecondary)
        }
    }

    private func statusLine(isRecording: Bool) -> String {
        if isRecording { return "Recording — click Stop when you're done talking." }
        if !controller.transcript.isEmpty { return controller.transcript }
        return WisprReader.isInstalled
            ? "Click Record, talk, click Stop. Apple, Parakeet and Wispr Flow all hear it."
            : "Click Record, talk, click Stop. Wispr Flow isn't installed, so it's Apple vs Parakeet."
    }

    private var emptyState: some View {
        VStack(spacing: DS.Space.snug) {
            Silkscreen(text: "Hold \(settings.pushToTalkKey.displayName) and talk", large: true)
            Text(settings.compareMode
                 ? "Both engines run on that one recording and appear here."
                 : "Turn on Compare mode in the menu bar to see both engines at once.")
                .font(DS.Font.label)
                .foregroundStyle(DS.Color.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.panel)
    }
}

private struct ComparisonCard: View {
    let runs: [DictationRun]

    private var ranked: [DictationRun] {
        runs.sorted { $0.processSeconds < $1.processSeconds }
    }

    private var margin: String? {
        guard runs.count > 1,
              let best = ranked.first,
              let worst = ranked.last,
              best.processSeconds > 0
        else { return nil }
        let ratio = worst.processSeconds / best.processSeconds
        let delta = worst.processSeconds - best.processSeconds
        guard delta > 0.005 else { return "tied" }
        return String(format: "%@ %.1f× faster · %.2fs ahead", best.engine, ratio, delta)
    }

    private var verdictLabel: String {
        if Set(runs.map(\.text)).count == 1 { return "identical" }
        let normalized = Set(runs.map {
            $0.text.lowercased().split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
        })
        return normalized.count == 1 ? "same words" : "words differ"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.base) {
            HStack {
                Text(runs.first.map { "\($0.date.formatted(date: .omitted, time: .standard)) · held \($0.audioSeconds, format: .number.precision(.fractionLength(1)))s" } ?? "")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkSecondary)
                Spacer()
                Silkscreen(text: verdictLabel, color: DS.Color.copper)
                if let group = runs.first?.group {
                    Button {
                        withAnimation { RunLog.deleteGroup(group) }
                    } label: {
                        Image(systemName: "trash")
                            .font(DS.Font.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .help("Delete this comparison")
                }
            }
            if let margin {
                Silkscreen(text: margin, color: DS.Color.copper)
            } else if runs.count == 1 {
                Silkscreen(text: "running second engine…", color: DS.Color.inkSecondary)
            }

            ForEach(Array(ranked.enumerated()), id: \.offset) { index, run in
                EngineRow(run: run, rank: index + 1, showRank: runs.count > 1)
            }
        }
        .padding(DS.Space.roomy)
        .background(BrushedPanel())
    }
}

private struct EngineRow: View {
    let run: DictationRun
    let rank: Int
    let showRank: Bool

    private var isWinner: Bool { showRank && rank == 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.tight) {
            HStack(alignment: .firstTextBaseline) {
                Silkscreen(
                    text: run.engine + (isWinner ? " · fastest" : ""),
                    color: isWinner ? DS.Color.copper : DS.Color.inkSecondary
                )
                Spacer()
                Text("\(run.processSeconds, format: .number.precision(.fractionLength(2)))s")
                    .font(isWinner ? DS.Font.counterLarge : DS.Font.counter)
                    .foregroundStyle(isWinner ? DS.Color.copper : DS.Color.ink)
            }
            Text("\(run.realtimeFactor, format: .number.precision(.fractionLength(0)))× realtime · \(run.characters) chars")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkSecondary)
            Text(run.text.isEmpty ? "(nothing recognized)" : run.text)
                .font(DS.Font.body)
                .foregroundStyle(run.text.isEmpty ? DS.Color.inkSecondary : DS.Color.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, DS.Space.tight)
    }
}

private struct SingleCard: View {
    let run: DictationRun

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            HStack {
                Silkscreen(text: run.engine)
                Spacer()
                Text("\(run.processSeconds, format: .number.precision(.fractionLength(2)))s")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkSecondary)
            }
            Text(run.text)
                .font(DS.Font.body)
                .foregroundStyle(DS.Color.ink)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DS.Space.base)
        .background(BrushedPanel())
    }
}
