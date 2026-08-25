import YappieActivity
import SwiftUI

/// Words, streak, and the year of dictation.
///
/// Two structural changes from the first version. The ledger is read from `RunStore`
/// instead of being rebuilt by each computed property — building it walks 53 weeks and
/// every utterance, and this view used to do that eight times per redraw. And the year grid
/// is one `Canvas` instead of 371 `Button`s, which is both faster and lets the grid size
/// itself to the window rather than living in a nested horizontal scroll view.
struct ActivityPanel: View {
    @State private var store = RunStore.shared
    @State private var hovered: ActivityDay?
    @State private var selected: ActivityDay?

    private var ledger: ActivityLedger { store.ledger }

    private var focused: ActivityDay? {
        hovered ?? selected ?? ledger.day(on: Date())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.wide) {
                    stats
                    year
                    lastSeven
                }
                .padding(DS.Space.roomy)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            caption
        }
    }

    // MARK: - Stats

    private var stats: some View {
        HStack(alignment: .top, spacing: DS.Space.base) {
            StatBlock(value: ledger.wordsToday.formatted(), label: "Today")
            StatBlock(
                value: ledger.currentStreak == 0 ? "—" : "\(ledger.currentStreak)",
                label: "Day streak",
                detail: ledger.longestStreak > 0 ? "Best \(dayCount(ledger.longestStreak))" : nil
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

    // MARK: - Year

    private var year: some View {
        VStack(alignment: .leading, spacing: DS.Space.snug) {
            PageHeading(title: "Year", trailing: speakingDaySummary)

            YearRamp(
                weeks: ledger.weeks,
                monthLabels: ledger.monthLabels,
                weekdaySymbols: ledger.weekdaySymbols,
                weekdayLabelMask: ledger.weekdayLabelMask,
                focused: focused,
                onHover: { hovered = $0 },
                onSelect: { day in if !day.isFuture { selected = day } }
            )

            legend
        }
    }

    private var speakingDaySummary: String {
        guard ledger.speakingDayCount > 0 else { return "" }
        return ledger.speakingDayCount == 1
            ? "1 day spoken"
            : "\(ledger.speakingDayCount) days spoken"
    }

    private var legend: some View {
        HStack(spacing: DS.Space.snug) {
            Spacer(minLength: 0)
            Text("Less")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkOnPageFaint)
            HStack(spacing: DS.Size.rampGap) {
                ForEach(HeatmapLevel.allCases, id: \.rawValue) { level in
                    RoundedRectangle(cornerRadius: DS.Radius.ramp, style: .continuous)
                        .fill(level.fill)
                        .frame(width: DS.Size.rampLegendCell, height: DS.Size.rampLegendCell)
                }
            }
            Text("More")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkOnPageFaint)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Last seven days

    private var lastSeven: some View {
        let days = ledger.lastSevenDays
        let peak = max(days.map(\.wordCount).max() ?? 0, 1)

        return VStack(alignment: .leading, spacing: DS.Space.snug) {
            PageHeading(title: "Last seven days", trailing: "peak \(peak.formatted())")

            HStack(alignment: .bottom, spacing: DS.Space.snug) {
                ForEach(days) { day in
                    WeekBar(
                        day: day,
                        height: barHeight(words: day.wordCount, peak: peak),
                        isFocused: focused?.start == day.start,
                        onSelect: { selected = day },
                        onHover: { hovered = $0 ? day : nil }
                    )
                }
            }
            .overlay(alignment: .bottom) {
                // A baseline, so short bars read as small rather than as floating blocks.
                Rule(onPage: true)
                    .padding(.bottom, DS.Space.roomy)
            }
        }
    }

    private func barHeight(words: Int, peak: Int) -> CGFloat {
        guard words > 0 else { return DS.Border.hairline }
        return max(DS.Space.tight, DS.Size.weekBarHeight * CGFloat(words) / CGFloat(peak))
    }

    // MARK: - Caption

    /// Pinned below the scroll view. It used to be the last item *inside* it, which is why
    /// the day you were pointing at was cut in half by the bottom edge of the page.
    private var caption: some View {
        HStack(spacing: DS.Space.snug) {
            if ledger.wordsAllTime == 0 {
                Eyebrow(text: "Nothing yet", color: DS.Color.inkOnPageMuted)
                Text("Days you dictate light up.")
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkOnPageFaint)
            } else if let focused {
                Eyebrow(text: captionTitle(for: focused), color: DS.Color.inkOnPage)
                Text(captionDetail(for: focused))
                    .font(DS.Font.label)
                    .foregroundStyle(DS.Color.inkOnPageMuted)
            }
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .padding(.horizontal, DS.Space.roomy)
        .padding(.vertical, DS.Space.base)
        .background(DS.Color.page)
        .overlay(alignment: .top) { Rule(onPage: true) }
    }

    private func captionTitle(for day: ActivityDay) -> String {
        if day.isToday { return "Today" }
        return day.start.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    private func captionDetail(for day: ActivityDay) -> String {
        if day.isFuture { return "Hasn't happened yet." }
        if day.wordCount == 0 { return "No words." }
        return "\(day.wordCount.formatted()) word\(day.wordCount == 1 ? "" : "s")"
    }

    private func dayCount(_ n: Int) -> String {
        n == 1 ? "1 day" : "\(n) days"
    }
}

// MARK: - The year grid

/// A year of daily word counts, drawn in one `Canvas`.
///
/// Sizes its cells to the width it is given, between 7 and 14 points, so the whole year is
/// visible without a horizontal scroll view nested inside a vertical one.
private struct YearRamp: View {
    let weeks: [ActivityWeek]
    let monthLabels: [MonthLabel]
    let weekdaySymbols: [String]
    let weekdayLabelMask: [Bool]
    let focused: ActivityDay?
    let onHover: (ActivityDay?) -> Void
    let onSelect: (ActivityDay) -> Void

    /// Measured, not read from a `GeometryReader` wrapped around the grid: the grid's height
    /// is a function of its width, so reading the width from inside the same pass that sets
    /// the height is circular and clips the bottom row.
    @State private var width: CGFloat = 0

    var body: some View {
        let layout = Layout(width: width, weekCount: weeks.count)

        return ZStack(alignment: .topLeading) {
            monthRow(layout)
            weekdayColumn(layout)
            grid(layout)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: layout.totalHeight)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.size.width, initial: true) { _, new in
                        width = new
                    }
            }
        }
        .contentShape(.rect)
        .onContinuousHover { phase in
            switch phase {
            case .active(let point): onHover(day(at: point, layout: layout))
            case .ended: onHover(nil)
            }
        }
        .onTapGesture(count: 1, coordinateSpace: .local) { point in
            if let day = day(at: point, layout: layout) { onSelect(day) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Words dictated each day over the past year")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        let spoken = weeks.flatMap(\.days).filter(\.isSpeakingDay).count
        return spoken == 1 ? "1 day with words" : "\(spoken) days with words"
    }

    private func monthRow(_ layout: Layout) -> some View {
        ForEach(monthLabels) { label in
            Text(label.name)
                .font(DS.Font.weekday)
                .foregroundStyle(DS.Color.inkOnPageFaint)
                .offset(x: layout.x(week: label.weekIndex), y: 0)
        }
    }

    private func weekdayColumn(_ layout: Layout) -> some View {
        ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
            Text(showsLabel(at: index) ? symbol : "")
                .font(DS.Font.weekday)
                .foregroundStyle(DS.Color.inkOnPageFaint)
                .frame(width: DS.Size.rampWeekdayWidth, height: layout.cell, alignment: .leading)
                .offset(x: 0, y: layout.y(weekday: index))
        }
    }

    private func grid(_ layout: Layout) -> some View {
        Canvas { context, _ in
            for (weekIndex, week) in weeks.enumerated() {
                for (dayIndex, day) in week.days.enumerated() {
                    let rect = CGRect(
                        x: layout.x(week: weekIndex),
                        y: layout.y(weekday: dayIndex),
                        width: layout.cell,
                        height: layout.cell
                    )
                    let path = Path(roundedRect: rect, cornerRadius: DS.Radius.ramp)
                    context.fill(
                        path,
                        with: .color(day.isFuture ? DS.Color.rampFuture : day.level.fill)
                    )
                    if let stroke = strokeColor(for: day) {
                        context.stroke(path, with: .color(stroke), lineWidth: DS.Border.hairline)
                    }
                }
            }
        }
    }

    private func strokeColor(for day: ActivityDay) -> Color? {
        if day.isToday { return DS.Color.copper }
        if focused?.start == day.start { return DS.Color.inkOnPageMuted }
        return nil
    }

    private func showsLabel(at index: Int) -> Bool {
        weekdayLabelMask.indices.contains(index) && weekdayLabelMask[index]
    }

    private func day(at point: CGPoint, layout: Layout) -> ActivityDay? {
        guard let week = layout.weekIndex(atX: point.x),
              let weekday = layout.weekdayIndex(atY: point.y),
              weeks.indices.contains(week),
              weeks[week].days.indices.contains(weekday)
        else { return nil }
        return weeks[week].days[weekday]
    }

    /// Cell geometry for one width. A value type so hit testing and drawing cannot drift.
    private struct Layout {
        let cell: CGFloat
        let gap: CGFloat
        let weekCount: Int

        init(width: CGFloat, weekCount: Int) {
            self.weekCount = max(weekCount, 1)
            gap = DS.Size.rampGap
            let available = max(0, width - DS.Size.rampWeekdayWidth)
            let pitch = available / CGFloat(self.weekCount)
            cell = min(DS.Size.rampCellMax, max(DS.Size.rampCellMin, pitch - gap))
        }

        var pitch: CGFloat { cell + gap }
        var gridHeight: CGFloat { pitch * 7 - gap }
        var totalHeight: CGFloat { DS.Size.rampMonthHeight + gridHeight }

        func x(week: Int) -> CGFloat { DS.Size.rampWeekdayWidth + CGFloat(week) * pitch }
        func y(weekday: Int) -> CGFloat { DS.Size.rampMonthHeight + CGFloat(weekday) * pitch }

        func weekIndex(atX x: CGFloat) -> Int? {
            let local = x - DS.Size.rampWeekdayWidth
            guard local >= 0 else { return nil }
            let index = Int(local / pitch)
            return index < weekCount ? index : nil
        }

        func weekdayIndex(atY y: CGFloat) -> Int? {
            let local = y - DS.Size.rampMonthHeight
            guard local >= 0 else { return nil }
            let index = Int(local / pitch)
            return index < 7 ? index : nil
        }
    }
}

// MARK: - Pieces

private struct StatBlock: View {
    let value: String
    let label: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.hair) {
            Eyebrow(text: label, color: DS.Color.inkOnPageMuted)
            Readout(text: value, large: true)
            Text(detail ?? " ")
                .font(DS.Font.caption)
                .foregroundStyle(DS.Color.inkOnPageFaint)
                .opacity(detail == nil ? 0 : 1)
        }
        .frame(minWidth: DS.Size.statColumn, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct WeekBar: View {
    let day: ActivityDay
    let height: CGFloat
    let isFocused: Bool
    let onSelect: () -> Void
    let onHover: (Bool) -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DS.Space.tight) {
                // Above the bar, not above the *column* — with the spacer between them the
                // number floated at the top of the block, nowhere near what it labels.
                Spacer(minLength: 0)

                Text(day.wordCount == 0 ? "" : day.wordCount.formatted())
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Color.inkOnPageFaint)
                    .monospacedDigit()

                RoundedRectangle(cornerRadius: DS.Radius.ramp, style: .continuous)
                    .fill(day.wordCount == 0 ? DS.Color.rampEmpty : day.level.fill)
                    .frame(height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.ramp, style: .continuous)
                            .strokeBorder(stroke, lineWidth: DS.Border.hairline)
                    )

                Text(shortWeekday)
                    .font(DS.Font.caption)
                    .foregroundStyle(day.isToday ? DS.Color.copper : DS.Color.inkOnPageFaint)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DS.Size.weekBarHeight + DS.Space.panel + DS.Space.roomy)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .onHover(perform: onHover)
        .accessibilityLabel(accessibility)
    }

    private var stroke: Color {
        if day.isToday { return DS.Color.copper }
        if isFocused { return DS.Color.inkOnPageMuted }
        return .clear
    }

    private var shortWeekday: String {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let weekday = calendar.component(.weekday, from: day.start)
        guard symbols.indices.contains(weekday - 1) else { return "" }
        return symbols[weekday - 1]
    }

    private var accessibility: String {
        let date = day.start.formatted(.dateTime.weekday(.wide).month(.wide).day())
        if day.isFuture { return "\(date), upcoming" }
        if day.wordCount == 0 { return "\(date), no words" }
        return "\(date), \(day.wordCount.formatted()) words"
    }
}

private extension HeatmapLevel {
    var fill: Color {
        switch self {
        case .empty: DS.Color.rampEmpty
        case .faint: DS.Color.rampFaint
        case .low: DS.Color.rampLow
        case .mid: DS.Color.rampMid
        case .full: DS.Color.rampFull
        }
    }
}
