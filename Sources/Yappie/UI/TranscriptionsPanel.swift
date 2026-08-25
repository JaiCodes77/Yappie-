import YappieDictionary
import YappieActivity
import AppKit
import SwiftUI

/// Past transcriptions, grouped by the day you said them.
///
/// The flat reverse-chronological list showed a bare clock time on every row, so a
/// three-week history read as one undifferentiated column of times with no way to tell
/// Tuesday from last month.
struct TranscriptionsPanel: View {
    @State private var store = RunStore.shared
    @State private var navigation = Navigation.shared
    @State private var query = ""
    @State private var isConfirmingClear = false
    @FocusState private var searchFocused: Bool

    private var matches: [DictationRun] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.runs }
        return store.runs.filter { $0.text.localizedStandardContains(trimmed) }
    }

    private var groups: [DayGroup] { DayGroup.build(from: matches) }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(text: $query, placeholder: "Search transcriptions", focus: $searchFocused)

            if groups.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DS.Space.roomy, pinnedViews: .sectionHeaders) {
                        ForEach(groups) { group in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(group.runs) { run in
                                        TranscriptionRow(run: run) {
                                            withAnimation(DS.Motion.panel) { RunLog.delete(run) }
                                        }
                                    }
                                }
                            } header: {
                                dayHeader(group)
                            }
                        }
                    }
                    .padding(.bottom, DS.Space.base)
                }
                footer
            }
        }
        .onChange(of: navigation.focusSearchToken) { _, _ in
            if navigation.section == .transcriptions { searchFocused = true }
        }
    }

    private func dayHeader(_ group: DayGroup) -> some View {
        PageHeading(title: group.title, trailing: group.wordSummary)
            .padding(.horizontal, DS.Space.roomy)
            .padding(.vertical, DS.Space.snug)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Color.page)
            .overlay(alignment: .bottom) { Rule(onPage: true) }
    }

    @ViewBuilder
    private var emptyState: some View {
        if store.runs.isEmpty {
            EmptyPage(
                symbol: "waveform",
                title: "Nothing dictated yet",
                detail: "Hold \(Settings.shared.pushToTalkKey.displayName) anywhere and talk. "
                    + "Release, and the text lands wherever your caret is — and here."
            )
        } else {
            EmptyPage(
                symbol: "magnifyingglass",
                title: "No matches",
                detail: "Nothing in \(store.runs.count) recordings contains “\(query)”."
            ) {
                PillButton(title: "Clear search") { query = "" }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: DS.Space.snug) {
            Eyebrow(
                text: "\(store.runs.count) recording\(store.runs.count == 1 ? "" : "s")",
                color: DS.Color.inkOnPageMuted
            )
            if !query.isEmpty {
                Eyebrow(text: "· \(matches.count) shown", color: DS.Color.inkOnPageFaint)
            }
            Spacer()
            PageButton(title: "Delete all", systemImage: "trash") { isConfirmingClear = true }
        }
        .padding(.horizontal, DS.Space.base)
        .padding(.vertical, DS.Space.snug)
        .background(DS.Color.page)
        .overlay(alignment: .top) { Rule(onPage: true) }
        // Confirmed, unlike a single row: one row is trivially re-recorded, the whole
        // history is not, and there's no undo.
        .confirmationDialog(
            "Delete all \(store.runs.count) recordings?",
            isPresented: $isConfirmingClear,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive) { RunLog.clear() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
    }
}

// MARK: - Day grouping

/// One calendar day's transcripts, newest day first and newest run first within the day.
private struct DayGroup: Identifiable {
    let id: Date
    let title: String
    let runs: [DictationRun]
    let words: Int

    var wordSummary: String {
        words == 1 ? "1 word" : "\(words.formatted()) words"
    }

    static func build(from runs: [DictationRun]) -> [DayGroup] {
        let calendar = Calendar.current
        let byDay = Dictionary(grouping: runs) { calendar.startOfDay(for: $0.date) }

        return byDay.keys.sorted(by: >).map { day in
            let dayRuns = (byDay[day] ?? []).sorted { $0.date > $1.date }
            // Compare-mode runs share a group id and the same words; counting each engine
            // separately would treble the day's total.
            let words = SpokenUtterance
                .collapsingDuplicates(dayRuns.map(\.spoken))
                .reduce(0) { $0 + SpokenWordCount.count(in: $1.text) }
            return DayGroup(id: day, title: title(for: day, calendar: calendar), runs: dayRuns, words: words)
        }
    }

    private static func title(for day: Date, calendar: Calendar) -> String {
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        // Inside the last week the weekday alone is the most readable label.
        if let days = calendar.dateComponents([.day], from: day, to: Date()).day, days < 7 {
            return day.formatted(.dateTime.weekday(.wide))
        }
        if calendar.isDate(day, equalTo: Date(), toGranularity: .year) {
            return day.formatted(.dateTime.weekday(.abbreviated).day().month(.wide))
        }
        return day.formatted(.dateTime.day().month(.wide).year())
    }
}

// MARK: - Row

private struct TranscriptionRow: View {
    let run: DictationRun
    let onDelete: () -> Void

    @State private var didCopy = false
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            header

            Text(run.text.isEmpty ? "(nothing recognized)" : run.text)
                .font(DS.Font.body)
                .foregroundStyle(run.text.isEmpty ? DS.Color.inkOnPageFaint : DS.Color.inkOnPage)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let corrections = run.corrections, !corrections.isEmpty {
                CorrectionBadges(corrections: corrections)
            }
        }
        .padding(.horizontal, DS.Space.roomy)
        .padding(.vertical, DS.Space.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isHovering ? DS.Color.pageHover : Color.clear)
        .overlay(alignment: .bottom) { Rule(onPage: true) }
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Copy") { copy() }
            Button("Teach dictionary…") { DictionaryStore.shared.beginTeach(transcript: run.text) }
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
    }

    private var header: some View {
        HStack(spacing: DS.Space.snug) {
            Text(run.date, format: .dateTime.hour().minute())
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkOnPageMuted)
                .monospacedDigit()

            dot
            Eyebrow(text: run.engine, color: DS.Color.inkOnPageMuted)
            dot
            Text(String(format: "%.2fs", run.processSeconds))
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkOnPageFaint)
                .monospacedDigit()

            Spacer(minLength: DS.Space.snug)

            actions
        }
    }

    private var dot: some View {
        Circle()
            .fill(DS.Color.inkOnPageFaint)
            .frame(width: 2, height: 2)
    }

    /// Always in the view tree — only the opacity changes on hover.
    ///
    /// These used to be built inside `if isHovering`, which means a keyboard or VoiceOver
    /// user had no way to reach Copy, Teach or Delete at all: a view that isn't built
    /// doesn't exist to assistive technology.
    private var actions: some View {
        HStack(spacing: DS.Space.tight) {
            PageButton(
                title: didCopy ? "Copied" : "Copy",
                systemImage: didCopy ? "checkmark" : "doc.on.doc",
                isProminent: didCopy,
                help: "Copy this transcript"
            ) { copy() }

            PageButton(title: "Teach", systemImage: "character.book.closed", help: "Add words from this transcript to the dictionary") {
                DictionaryStore.shared.beginTeach(transcript: run.text)
            }

            PageButton(title: "", systemImage: "trash", help: "Delete this transcription", action: onDelete)
        }
        .opacity(isHovering || didCopy ? 1 : DS.Color.Alpha.quiet)
        .animation(DS.Motion.release, value: isHovering)
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(run.text, forType: .string)
        didCopy = true
        Task {
            try? await Task.sleep(for: .seconds(1.4))
            didCopy = false
        }
    }
}

/// Shows that the dictionary fired, and on what. Without this the dictionary is invisible
/// and you can't tell a rule that works from one that never matches.
private struct CorrectionBadges: View {
    let corrections: [AppliedCorrection]

    var body: some View {
        HStack(spacing: DS.Space.snug) {
            Eyebrow(text: "Corrected", color: DS.Color.caution)
            ForEach(corrections, id: \.self) { correction in
                HStack(spacing: DS.Space.tight) {
                    Text(correction.from)
                        .strikethrough()
                        .foregroundStyle(DS.Color.inkOnPageMuted)
                    Image(systemName: "arrow.right")
                        .font(DS.Font.iconMicro)
                        .foregroundStyle(DS.Color.inkOnPageFaint)
                    Text(correction.to)
                        .foregroundStyle(DS.Color.inkOnPage)
                    if correction.count > 1 {
                        Text("×\(correction.count)")
                            .foregroundStyle(DS.Color.inkOnPageMuted)
                    }
                }
                .font(DS.Font.caption)
                .padding(.horizontal, DS.Space.snug)
                .padding(.vertical, DS.Space.hair)
                .background(DS.Color.caution.opacity(DS.Color.Alpha.wash), in: .rect(cornerRadius: DS.Radius.chip))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.chip)
                        .strokeBorder(DS.Color.caution.opacity(DS.Color.Alpha.edge), lineWidth: DS.Border.hairline)
                )
            }
            Spacer(minLength: 0)
        }
    }
}
