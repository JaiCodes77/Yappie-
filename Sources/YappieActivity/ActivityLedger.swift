import Foundation

/// Phosphor density for one calendar day. 0 is empty; 4 is a heavy dictation day.
///
/// Fixed thresholds rather than per-user quartiles, so a three-word test utterance stays
/// dim and a 400-word day always reads as full. The UI maps these onto violet, never red.
public enum HeatmapLevel: Int, Equatable, Sendable, CaseIterable {
    case empty = 0
    case faint = 1
    case low = 2
    case mid = 3
    case full = 4

    /// Minimum word count for levels 1…4.
    public static let thresholds = [1, 50, 150, 400]

    public static func of(wordCount: Int) -> HeatmapLevel {
        if wordCount >= thresholds[3] { return .full }
        if wordCount >= thresholds[2] { return .mid }
        if wordCount >= thresholds[1] { return .low }
        if wordCount >= thresholds[0] { return .faint }
        return .empty
    }
}

/// One local calendar day in the heatmap window.
public struct ActivityDay: Equatable, Sendable, Identifiable {
    public var id: Date { start }
    /// `calendar.startOfDay` for this cell.
    public var start: Date
    public var wordCount: Int
    public var level: HeatmapLevel
    /// After today — shown so the current week is a full column, but not a speaking day.
    public var isFuture: Bool
    public var isToday: Bool
    /// False for padding cells. The rolling week grid fills every cell, so this is true
    /// for the whole heatmap; kept so a calendar-year layout can dim days outside the year.
    public var inWindow: Bool

    public init(
        start: Date,
        wordCount: Int,
        isFuture: Bool,
        isToday: Bool,
        inWindow: Bool
    ) {
        self.start = start
        self.wordCount = inWindow && !isFuture ? wordCount : 0
        self.level = HeatmapLevel.of(wordCount: self.wordCount)
        self.isFuture = isFuture
        self.isToday = isToday
        self.inWindow = inWindow
    }

    public var isSpeakingDay: Bool { inWindow && !isFuture && wordCount > 0 }
}

/// Seven consecutive days, Sunday-or-Monday-first depending on the calendar.
public struct ActivityWeek: Equatable, Sendable, Identifiable {
    public var id: Date { start }
    public var start: Date
    public var days: [ActivityDay]

    public init(start: Date, days: [ActivityDay]) {
        self.start = start
        self.days = days
    }
}

/// Month abbreviation sitting above the week that contains the 1st.
public struct MonthLabel: Equatable, Sendable, Identifiable {
    public var id: Int { weekIndex }
    public var weekIndex: Int
    public var name: String

    public init(weekIndex: Int, name: String) {
        self.weekIndex = weekIndex
        self.name = name
    }
}

/// Words-per-day, streak, and the year heatmap, derived from finished dictations.
///
/// Pure function of utterances + a clock + a calendar. The app feeds it `RunStore` rows;
/// tests pin the calendar to GMT so DST can't flap a day boundary.
public struct ActivityLedger: Equatable, Sendable {
    public var wordsToday: Int
    public var wordsThisWeek: Int
    public var wordsAllTime: Int
    /// Collapsed utterances that contained at least one word.
    public var spokenUtterances: Int
    public var currentStreak: Int
    public var longestStreak: Int
    public var speakingDayCount: Int
    public var weeks: [ActivityWeek]
    public var monthLabels: [MonthLabel]
    /// Inclusive of today, oldest first. Always seven cells.
    public var lastSevenDays: [ActivityDay]
    /// Weekday captions in calendar order (`S M T W T F S` or Monday-first).
    public var weekdaySymbols: [String]
    /// Which of those seven rows show a caption. Monday, Wednesday, Friday — the rest
    /// are 10-point cells, too small to wear a label each.
    public var weekdayLabelMask: [Bool]

    public init(
        utterances: [SpokenUtterance],
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current,
        weekCount: Int = 53
    ) {
        let collapsed = SpokenUtterance.collapsingDuplicates(utterances)
        let today = calendar.startOfDay(for: now)

        var wordsByDay: [Date: Int] = [:]
        var spoken = 0
        var allTime = 0
        for utterance in collapsed {
            let words = SpokenWordCount.count(in: utterance.text)
            guard words > 0 else { continue }
            spoken += 1
            allTime += words
            let day = calendar.startOfDay(for: utterance.date)
            wordsByDay[day, default: 0] += words
        }

        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        var wordsThisWeek = 0
        var wordsToday = 0
        for (day, words) in wordsByDay {
            if day == today { wordsToday = words }
            if day >= thisWeekStart && day <= today { wordsThisWeek += words }
        }

        let speakingDays = Set(wordsByDay.keys.filter { wordsByDay[$0, default: 0] > 0 })

        self.wordsToday = wordsToday
        self.wordsThisWeek = wordsThisWeek
        self.wordsAllTime = allTime
        self.spokenUtterances = spoken
        self.currentStreak = Self.currentStreak(
            speakingDays: speakingDays,
            today: today,
            calendar: calendar
        )
        self.longestStreak = Self.longestStreak(
            speakingDays: speakingDays,
            calendar: calendar
        )
        self.speakingDayCount = speakingDays.count
        self.weeks = Self.heatmapWeeks(
            weekCount: max(weekCount, 1),
            today: today,
            wordsByDay: wordsByDay,
            calendar: calendar
        )
        self.monthLabels = Self.monthLabels(weeks: self.weeks, calendar: calendar, locale: locale)
        self.lastSevenDays = Self.lastSevenDays(
            today: today,
            wordsByDay: wordsByDay,
            calendar: calendar
        )
        self.weekdaySymbols = Self.weekdaySymbols(calendar: calendar)
        self.weekdayLabelMask = Self.weekdayLabelMask(calendar: calendar)
    }

    public func day(on date: Date, calendar: Calendar = .current) -> ActivityDay? {
        let start = calendar.startOfDay(for: date)
        for week in weeks {
            if let match = week.days.first(where: { $0.start == start }) {
                return match
            }
        }
        return lastSevenDays.first { $0.start == start }
    }

    // MARK: - Streaks

    /// Consecutive speaking days ending today, or yesterday if today is still empty.
    /// A missed yesterday with an empty today is a broken streak — today isn't over,
    /// but yesterday is, and that's the day that would have kept it alive.
    static func currentStreak(
        speakingDays: Set<Date>,
        today: Date,
        calendar: Calendar
    ) -> Int {
        var cursor = today
        if !speakingDays.contains(today) {
            guard
                let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
                speakingDays.contains(yesterday)
            else { return 0 }
            cursor = yesterday
        }

        var length = 0
        while speakingDays.contains(cursor) {
            length += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return length
    }

    static func longestStreak(speakingDays: Set<Date>, calendar: Calendar) -> Int {
        guard !speakingDays.isEmpty else { return 0 }

        let ordered = speakingDays.sorted()
        var best = 1
        var run = 1
        for index in 1..<ordered.count {
            let previous = ordered[index - 1]
            let day = ordered[index]
            let consecutive = calendar.date(byAdding: .day, value: 1, to: previous) == day
            if consecutive {
                run += 1
                best = max(best, run)
            } else {
                run = 1
            }
        }
        return best
    }

    // MARK: - Heatmap

    static func heatmapWeeks(
        weekCount: Int,
        today: Date,
        wordsByDay: [Date: Int],
        calendar: Calendar
    ) -> [ActivityWeek] {
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        guard
            let gridStart = calendar.date(
                byAdding: .weekOfYear,
                value: -(weekCount - 1),
                to: thisWeekStart
            )
        else { return [] }

        var weeks: [ActivityWeek] = []
        weeks.reserveCapacity(weekCount)
        for weekIndex in 0..<weekCount {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekIndex, to: gridStart)
            else { continue }

            var days: [ActivityDay] = []
            days.reserveCapacity(7)
            for dayIndex in 0..<7 {
                let start = calendar.date(byAdding: .day, value: dayIndex, to: weekStart) ?? weekStart
                let isFuture = start > today
                days.append(
                    ActivityDay(
                        start: start,
                        wordCount: wordsByDay[start, default: 0],
                        isFuture: isFuture,
                        isToday: start == today,
                        inWindow: true
                    )
                )
            }
            weeks.append(ActivityWeek(start: weekStart, days: days))
        }
        return weeks
    }

    static func lastSevenDays(
        today: Date,
        wordsByDay: [Date: Int],
        calendar: Calendar
    ) -> [ActivityDay] {
        (0..<7).reversed().map { offset in
            let start = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return ActivityDay(
                start: start,
                wordCount: wordsByDay[start, default: 0],
                isFuture: start > today,
                isToday: start == today,
                inWindow: true
            )
        }
    }

    static func monthLabels(
        weeks: [ActivityWeek],
        calendar: Calendar,
        locale: Locale
    ) -> [MonthLabel] {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM")

        var labels: [MonthLabel] = []
        for (index, week) in weeks.enumerated() {
            let firstOfMonth = week.days.first { day in
                day.inWindow && calendar.component(.day, from: day.start) == 1
            }
            guard let first = firstOfMonth else { continue }
            labels.append(MonthLabel(weekIndex: index, name: formatter.string(from: first.start)))
        }
        return labels
    }

    static func weekdaySymbols(calendar: Calendar) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        // `veryShortStandaloneWeekdaySymbols` is Sunday-first regardless of `firstWeekday`.
        let origin = calendar.firstWeekday - 1
        return (0..<7).map { symbols[($0 + origin) % 7] }
    }

    /// Monday, Wednesday, Friday in the calendar's week order.
    static func weekdayLabelMask(calendar: Calendar) -> [Bool] {
        (0..<7).map { offset in
            let weekday = ((calendar.firstWeekday - 1 + offset) % 7) + 1
            return weekday == 2 || weekday == 4 || weekday == 6
        }
    }
}
