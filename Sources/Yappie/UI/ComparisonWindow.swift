import SwiftUI

/// Engine A/B results, one card per recording.
///
/// The timings are not a like-for-like ranking and the window says so: Apple and Parakeet
/// are timed on local compute with the clock started after model load, while Wispr Flow
/// reports its own end-to-end latency including a network round trip.
struct ComparisonWindow: View {
    @Bindable var controller: DictationController
    @State private var store = RunStore.shared
    @State private var settings = Settings.shared

    var body: some View {
        VStack(spacing: 0) {
            header
            Rule()

            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.base) {
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
                .padding(DS.Space.roomy)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: DS.Size.comparisonMinWidth, minHeight: DS.Size.comparisonMinHeight)
        .background(DS.Color.chassis)
    }

    private var header: some View {
        HStack(spacing: DS.Space.base) {
            RecordButton(
                isCapturing: controller.state.isActive,
                isBusy: controller.state == .finishing
            ) {
                if controller.state.isActive {
                    controller.stopButtonRecording()
                } else {
                    controller.startButtonRecording()
                }
            }

            VStack(alignment: .leading, spacing: DS.Space.hair) {
                Eyebrow(text: settings.compareMode ? "Compare mode on" : "Compare mode off")
                Text(statusLine)
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: DS.Space.snug)

            if !store.runs.isEmpty {
                PillButton(title: "Clear", systemImage: "trash") {
                    RunLog.clear()
                }
            }
        }
        .padding(DS.Space.base)
        .background(DS.Color.bar)
    }

    private var statusLine: String {
        if controller.state.isActive { return "Recording — click Stop when you're done talking." }
        if !controller.transcript.isEmpty { return controller.transcript }
        if !settings.compareMode { return "Turn on compare mode in Settings to run every engine." }
        return WisprReader.isInstalled
            ? "Apple, Parakeet and Wispr Flow all hear the same recording."
            : "Apple vs Parakeet — Wispr Flow isn't installed."
    }

    private var emptyState: some View {
        EmptyPage(
            symbol: "arrow.triangle.2.circlepath",
            title: "No recordings to compare",
            detail: settings.compareMode
                ? "Hold \(settings.pushToTalkKey.displayName) and talk. Every engine runs on that one recording and appears here."
                : "Compare mode is off, so each recording uses one engine. Turn it on in Settings to see them side by side."
        )
        .frame(minHeight: 220)
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
        Card {
            VStack(alignment: .leading, spacing: DS.Space.base) {
                HStack(spacing: DS.Space.snug) {
                    Text(heading)
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Color.inkSecondary)
                    Spacer()
                    Eyebrow(text: verdictLabel, color: DS.Color.copper)
                    if let group = runs.first?.group {
                        Button {
                            withAnimation { RunLog.deleteGroup(group) }
                        } label: {
                            Image(systemName: "trash")
                                .font(DS.Font.iconTiny)
                                .foregroundStyle(DS.Color.inkSecondary)
                        }
                        .buttonStyle(.plain)
                        .help("Delete this comparison")
                    }
                }

                if let margin {
                    Eyebrow(text: margin, color: DS.Color.copper)
                } else if runs.count == 1 {
                    Eyebrow(text: "running the next engine…", color: DS.Color.inkSecondary)
                }

                ForEach(Array(ranked.enumerated()), id: \.offset) { index, run in
                    EngineRow(run: run, rank: index + 1, showRank: runs.count > 1)
                }
            }
            .padding(DS.Space.roomy)
        }
    }

    private var heading: String {
        guard let first = runs.first else { return "" }
        let time = first.date.formatted(date: .omitted, time: .standard)
        return "\(time) · held \(first.audioSeconds.formatted(.number.precision(.fractionLength(1))))s"
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
                Eyebrow(
                    text: run.engine + (isWinner ? " · fastest" : ""),
                    color: isWinner ? DS.Color.copper : DS.Color.inkSecondary
                )
                Spacer()
                Text("\(run.processSeconds, format: .number.precision(.fractionLength(2)))s")
                    .font(DS.Font.counter)
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
        Card {
            VStack(alignment: .leading, spacing: DS.Space.snug) {
                HStack {
                    Eyebrow(text: run.engine)
                    Spacer()
                    Text("\(run.processSeconds, format: .number.precision(.fractionLength(2)))s")
                        .font(DS.Font.counter)
                        .foregroundStyle(DS.Color.inkSecondary)
                }
                Text(run.text)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Color.ink)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DS.Space.base)
        }
    }
}
