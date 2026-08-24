import YappieActivity
import SwiftUI

/// Words, streak, and the year heatmap. Compare-mode engine rows are collapsed in the
/// ledger so a side-by-side run doesn't look like three times the talking.
struct ActivityPanel: View {
    @State private var store = RunStore.shared
    @State private var hovered: ActivityDay?
    @State private var selected: ActivityDay?

    private var ledger: ActivityLedger {
        ActivityLedger(utterances: store.runs.map(\.spoken))
    }

    private var focused: ActivityDay? {
        hovered ?? selected ?? ledger.day(on: Date())
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.wide) {
                stats
                heatmap
                weekBars
                focusedCaption
            }
            .padding(DS.Space.roomy)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear { selected = ledger.day(on: Date()) }
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(alignment: .top, spacing: DS.Space.wide) {
            StatBlock(value: ledger.wordsToday.formatted(), label: "Today")
            StatBlock(
                value: streakValue,
                label: "Streak",
                detail: ledger.longestStreak > 0
                    ? "Longest \(dayCount(ledger.longestStreak))"
                    : nil
            )
            StatBlock(value: ledger.wordsThisWeek.formatted(), label: "This week")
            StatBlock(
                value: ledger.wordsAllTime.formatted(),
                label: "All time",
                detail: ledger.spokenUtterances == 0
                    ? nil
                    : "\(ledger.spokenUtterances.formatted()) utterance\(ledger.spokenUtterances == 1 ? "" : "s")"
            )
            Spacer(minLength: 0)
        }
    }

    private var streakValue: String {
        ledger.currentStreak == 0 ? "—" : "\(ledger.currentStreak)"
    }

    // MARK: - Heatmap

    private var heatmap: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            Silkscreen(text: "Year", color: DS.Color.inkOnDeckMuted)
            ScrollView(.horizontal, showsIndicators: false) {
                heatmapGrid
            }
            legend
        }
    }

    private var heatmapGrid: some View {
        let cell = DS.Size.heatmapCell
        let gap = DS.Size.heatmapGap

        return VStack(alignment: .leading, spacing: DS.Space.tight) {
            HStack(spacing: 0) {
                Color.clear.frame(width: DS.Size.heatmapWeekdayWidth, height: DS.Size.heatmapMonthHeight)
                ZStack(alignment: .topLeading) {
                    HStack(spacing: gap) {
                        ForEach(ledger.weeks) { _ in
                            Color.clear.frame(width: cell, height: DS.Size.heatmapMonthHeight)
                        }
                    }
                    ForEach(ledger.monthLabels) { label in
                        Silkscreen(text: label.name, color: DS.Color.inkOnDeckMuted)
                            .offset(x: CGFloat(label.weekIndex) * (cell + gap))
                    }
                }
            }

            HStack(alignment: .top, spacing: DS.Space.tight) {
                VStack(spacing: gap) {
                    ForEach(Array(ledger.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                        Text(showsWeekdayLabel(at: index) ? symbol : "")
                            .font(DS.Font.heatmapWeekday)
                            .foregroundStyle(DS.Color.inkOnDeckFaint)
                            .frame(width: DS.Size.heatmapWeekdayWidth, height: cell, alignment: .leading)
                    }
                }

                HStack(spacing: gap) {
                    ForEach(ledger.weeks) { week in
                        VStack(spacing: gap) {
                            ForEach(week.days) { day in
                                HeatmapCell(
                                    day: day,
                                    isFocused: focused?.start == day.start
                                ) {
                                    selected = day.isFuture ? selected : day
                                }
                                .onHover { hovering in
                                    hovered = hovering && !day.isFuture ? day : nil
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(.bottom, DS.Space.tight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Words dictated each day, past year")
    }

    private var legend: some View {
        HStack(spacing: DS.Space.snug) {
            Text("Less")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkOnDeckFaint)
            HStack(spacing: DS.Size.heatmapGap) {
                ForEach(HeatmapLevel.allCases, id: \.rawValue) { level in
                    RoundedRectangle(cornerRadius: DS.Radius.heatmap, style: .continuous)
                        .fill(level.fill)
                        .frame(width: DS.Size.heatmapLegendCell, height: DS.Size.heatmapLegendCell)
                }
            }
            Text("More")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkOnDeckFaint)
            Spacer()
        }
    }

    // MARK: - Week bars

    private var weekBars: some View {
        let days = ledger.lastSevenDays
        let peak = max(days.map(\.wordCount).max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: DS.Space.snug) {
            Silkscreen(text: "Last seven days", color: DS.Color.inkOnDeckMuted)
            HStack(alignment: .bottom, spacing: DS.Size.weekBarGap) {
                ForEach(days) { day in
                    let height = barHeight(words: day.wordCount, peak: peak)
                    VStack(spacing: DS.Space.tight) {
                        RoundedRectangle(cornerRadius: DS.Radius.heatmap, style: .continuous)
                            .fill(day.level.fill)
                            .frame(width: DS.Size.weekBarWidth, height: height)
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.heatmap, style: .continuous)
                                    .strokeBorder(
                                        day.isToday ? DS.Color.copper : Color.clear,
                                        lineWidth: DS.Border.hairline
                                    )
                            )
                        Text(shortWeekday(day.start))
                            .font(DS.Font.caption)
                            .foregroundStyle(
                                day.isToday ? DS.Color.copper : DS.Color.inkOnDeckFaint
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { selected = day }
                    .onHover { hovering in
                        hovered = hovering ? day : nil
                    }
                    .accessibilityLabel(accessibilityLabel(for: day))
                }
            }
            .frame(height: DS.Size.weekBarHeight + DS.Space.wide)
        }
    }

    private func barHeight(words: Int, peak: Int) -> CGFloat {
        guard words > 0 else { return DS.Space.hair }
        let ratio = CGFloat(words) / CGFloat(peak)
        return max(DS.Space.snug, DS.Size.weekBarHeight * ratio)
    }

    // MARK: - Caption

    private var focusedCaption: some View {
        VStack(alignment: .leading, spacing: DS.Space.tight) {
            if ledger.wordsAllTime == 0 {
                Silkscreen(text: "No recordings yet", color: DS.Color.inkOnDeckMuted)
                Text("Hold \(Settings.shared.pushToTalkKey.displayName) and talk. Days you dictate light up.")
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkOnDeckFaint)
            } else if let focused {
                Silkscreen(text: captionTitle(for: focused), color: DS.Color.inkOnDeck)
                Text(captionDetail(for: focused))
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkOnDeckMuted)
            }
        }
    }

    private func showsWeekdayLabel(at index: Int) -> Bool {
        ledger.weekdayLabelMask.indices.contains(index) && ledger.weekdayLabelMask[index]
    }

    private func captionTitle(for day: ActivityDay) -> String {
        if day.isToday { return "Today" }
        return day.start.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func captionDetail(for day: ActivityDay) -> String {
        if day.isFuture { return "Hasn't happened yet." }
        if day.wordCount == 0 { return "No words." }
        let words = "\(day.wordCount.formatted()) word\(day.wordCount == 1 ? "" : "s")"
        return words
    }

    private func dayCount(_ n: Int) -> String {
        n == 1 ? "1 day" : "\(n) days"
    }

    private func shortWeekday(_ date: Date) -> String {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let weekday = calendar.component(.weekday, from: date)
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1]
    }

    private func accessibilityLabel(for day: ActivityDay) -> String {
        let date = day.start.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if day.isFuture { return "\(date), upcoming" }
        if day.wordCount == 0 { return "\(date), no words" }
        return "\(date), \(day.wordCount.formatted()) words"
    }
}

// MARK: - Header chip

/// Lives in the page header so today's count and the streak stay visible on every tab.
struct ActivityHeaderChip: View {
    let ledger: ActivityLedger

    var body: some View {
        HStack(spacing: DS.Space.base) {
            Readout(text: ledger.wordsToday.formatted())
            Silkscreen(text: "today", color: DS.Color.inkOnDeckMuted)
            Rectangle()
                .fill(DS.Color.deckHairline)
                .frame(width: DS.Border.seam, height: DS.Space.base)
            Readout(text: ledger.currentStreak == 0 ? "—" : "\(ledger.currentStreak)")
            Silkscreen(text: "streak", color: DS.Color.inkOnDeckMuted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibility)
    }

    private var accessibility: String {
        let today = "\(ledger.wordsToday.formatted()) words today"
        if ledger.currentStreak == 0 { return "\(today), no streak" }
        let days = ledger.currentStreak == 1 ? "1 day streak" : "\(ledger.currentStreak) day streak"
        return "\(today), \(days)"
    }
}

// MARK: - Pieces

private struct StatBlock: View {
    let value: String
    let label: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.hair) {
            Silkscreen(text: label, color: DS.Color.inkOnDeckMuted)
            Readout(text: value, large: true)
            if let detail {
                Text(detail)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkOnDeckFaint)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HeatmapCell: View {
    let day: ActivityDay
    let isFocused: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            RoundedRectangle(cornerRadius: DS.Radius.heatmap, style: .continuous)
                .fill(day.isFuture ? DS.Color.heatmapFuture : day.level.fill)
                .frame(width: DS.Size.heatmapCell, height: DS.Size.heatmapCell)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.heatmap, style: .continuous)
                        .strokeBorder(stroke, lineWidth: DS.Border.hairline)
                )
        }
        .buttonStyle(.plain)
        .disabled(day.isFuture)
        .help(help)
        .accessibilityLabel(label)
    }

    private var stroke: Color {
        if day.isToday { return DS.Color.copper }
        if isFocused { return DS.Color.heatmapFocusRing }
        return Color.clear
    }

    private var help: String {
        let date = day.start.formatted(date: .abbreviated, time: .omitted)
        if day.isFuture { return date }
        if day.wordCount == 0 { return "\(date): no words" }
        return "\(date): \(day.wordCount.formatted()) words"
    }

    private var label: String {
        let date = day.start.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if day.isFuture { return "\(date), upcoming" }
        if day.wordCount == 0 { return "\(date), no words" }
        return "\(date), \(day.wordCount.formatted()) words"
    }
}

private extension HeatmapLevel {
    var fill: Color {
        switch self {
        case .empty: DS.Color.heatmapEmpty
        case .faint: DS.Color.heatmapFaint
        case .low: DS.Color.heatmapLow
        case .mid: DS.Color.heatmapMid
        case .full: DS.Color.heatmapFull
        }
    }
}
