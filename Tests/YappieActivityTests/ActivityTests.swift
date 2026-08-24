import Foundation
import Testing
@testable import YappieActivity

struct ActivityTests {
    private let calendar = Calendar.gmtMonday
    private let locale = Locale(identifier: "en_US_POSIX")

    // Monday 24 August 2026, noon GMT — a fixed clock so streaks don't depend on when CI runs.
    private var now: Date { day(2026, 8, 24) }

    // MARK: - Word count

    @Test func emptyAndWhitespaceAreZero() {
        #expect(SpokenWordCount.count(in: "") == 0)
        #expect(SpokenWordCount.count(in: "   \n\t") == 0)
        #expect(SpokenWordCount.count(in: "...") == 0)
        #expect(SpokenWordCount.count(in: "—") == 0)
    }

    @Test func englishWords() {
        #expect(SpokenWordCount.count(in: "hello") == 1)
        #expect(SpokenWordCount.count(in: "hello world") == 2)
        #expect(SpokenWordCount.count(in: "Hello, world!") == 2)
        #expect(SpokenWordCount.count(in: "  hello   world  ") == 2)
        #expect(SpokenWordCount.count(in: "don't stop") == 2)
        #expect(SpokenWordCount.count(in: "API and SDK") == 3)
        #expect(SpokenWordCount.count(in: "123 456") == 2)
    }

    @Test func nfcAndNfdCountAsOneWord() {
        // Explicit code points so the compiler cannot NFC-normalise a café literal
        // and make the two strings identical before we count them.
        let composed = "caf\u{00E9}"
        let decomposed = "cafe\u{0301}"
        #expect(composed != decomposed)
        #expect(SpokenWordCount.count(in: composed) == 1)
        #expect(SpokenWordCount.count(in: decomposed) == 1)
    }

    // MARK: - Compare-mode collapse

    @Test func ungroupedRunsAdd() {
        let morning = SpokenUtterance(date: now, text: "one two")
        let afternoon = SpokenUtterance(date: now, text: "three four five")
        let ledger = makeLedger([morning, afternoon])
        #expect(ledger.wordsToday == 5)
        #expect(ledger.spokenUtterances == 2)
    }

    @Test func compareGroupCountsOnce() {
        let apple = SpokenUtterance(date: now, text: "one two", group: "g1")
        let parakeet = SpokenUtterance(date: now, text: "one two three four", group: "g1")
        let ledger = makeLedger([apple, parakeet])
        #expect(ledger.wordsToday == 4)
        #expect(ledger.spokenUtterances == 1)
        #expect(ledger.wordsAllTime == 4)
    }

    @Test func emptyTranscriptDoesNotSpeak() {
        let ledger = makeLedger([SpokenUtterance(date: now, text: "   ")])
        #expect(ledger.wordsToday == 0)
        #expect(ledger.spokenUtterances == 0)
        #expect(ledger.speakingDayCount == 0)
        #expect(ledger.currentStreak == 0)
    }

    // MARK: - Streaks

    @Test func emptyHistoryHasNoStreak() {
        let ledger = makeLedger([])
        #expect(ledger.currentStreak == 0)
        #expect(ledger.longestStreak == 0)
        #expect(ledger.wordsAllTime == 0)
        #expect(ledger.speakingDayCount == 0)
    }

    @Test func todayOnlyIsAOneDayStreak() {
        let ledger = makeLedger([SpokenUtterance(date: now, text: "hello there")])
        #expect(ledger.currentStreak == 1)
        #expect(ledger.longestStreak == 1)
        #expect(ledger.wordsToday == 2)
        #expect(ledger.speakingDayCount == 1)
    }

    @Test func yesterdayKeepsTheStreakAlive() {
        let yesterday = day(2026, 8, 23)
        let ledger = makeLedger([SpokenUtterance(date: yesterday, text: "kept going")])
        #expect(ledger.wordsToday == 0)
        #expect(ledger.currentStreak == 1)
        #expect(ledger.longestStreak == 1)
    }

    @Test func aMissedYesterdayBreaksTheStreak() {
        let twoDaysAgo = day(2026, 8, 22)
        let ledger = makeLedger([SpokenUtterance(date: twoDaysAgo, text: "too long ago")])
        #expect(ledger.currentStreak == 0)
        #expect(ledger.longestStreak == 1)
        #expect(ledger.speakingDayCount == 1)
    }

    @Test func consecutiveDaysCountBackward() {
        let utterances = [
            SpokenUtterance(date: day(2026, 8, 22), text: "one"),
            SpokenUtterance(date: day(2026, 8, 23), text: "two"),
            SpokenUtterance(date: now, text: "three"),
        ]
        let ledger = makeLedger(utterances)
        #expect(ledger.currentStreak == 3)
        #expect(ledger.longestStreak == 3)
    }

    @Test func longestStreakOutlivesTheCurrentOne() {
        // Five-day run in June, then a two-day run ending yesterday.
        var utterances: [SpokenUtterance] = (14...18).map { dayNum in
            SpokenUtterance(date: day(2026, 6, dayNum), text: "june")
        }
        utterances.append(SpokenUtterance(date: day(2026, 8, 23), text: "sun"))
        utterances.append(SpokenUtterance(date: now, text: "mon"))
        let ledger = makeLedger(utterances)
        #expect(ledger.currentStreak == 2)
        #expect(ledger.longestStreak == 5)
    }

    @Test func streakCrossesTheYearBoundary() {
        let utterances = [
            SpokenUtterance(date: day(2025, 12, 31), text: "nye"),
            SpokenUtterance(date: day(2026, 1, 1), text: "new year"),
        ]
        let newYears = day(2026, 1, 1)
        let ledger = ActivityLedger(
            utterances: utterances,
            now: newYears,
            calendar: calendar,
            locale: locale
        )
        #expect(ledger.currentStreak == 2)
        #expect(ledger.longestStreak == 2)
    }

    // MARK: - Week totals

    @Test func thisWeekStartsMonday() {
        // Sunday 23rd is the previous week when firstWeekday is Monday.
        let sunday = SpokenUtterance(date: day(2026, 8, 23), text: "one two three")
        let monday = SpokenUtterance(date: now, text: "four five")
        let ledger = makeLedger([sunday, monday])
        #expect(ledger.wordsToday == 2)
        #expect(ledger.wordsThisWeek == 2)
        #expect(ledger.wordsAllTime == 5)
    }

    // MARK: - Heatmap

    @Test func heatmapLevelsUseFixedThresholds() {
        #expect(HeatmapLevel.of(wordCount: 0) == .empty)
        #expect(HeatmapLevel.of(wordCount: 1) == .faint)
        #expect(HeatmapLevel.of(wordCount: 49) == .faint)
        #expect(HeatmapLevel.of(wordCount: 50) == .low)
        #expect(HeatmapLevel.of(wordCount: 149) == .low)
        #expect(HeatmapLevel.of(wordCount: 150) == .mid)
        #expect(HeatmapLevel.of(wordCount: 399) == .mid)
        #expect(HeatmapLevel.of(wordCount: 400) == .full)
    }

    @Test func heatmapIsFiftyThreeWeeksOfSevenDays() {
        let ledger = makeLedger([])
        #expect(ledger.weeks.count == 53)
        #expect(ledger.weeks.allSatisfy { $0.days.count == 7 })
        #expect(ledger.lastSevenDays.count == 7)
        #expect(ledger.lastSevenDays.last?.isToday == true)
        #expect(ledger.weekdaySymbols.count == 7)
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let origin = calendar.firstWeekday - 1
        let expectedWeekdays = (0..<7).map { symbols[($0 + origin) % 7] }
        #expect(ledger.weekdaySymbols == expectedWeekdays)
        #expect(ledger.weekdayLabelMask == [true, false, true, false, true, false, false])
    }

    @Test func todayCellIsMarkedAndFutureDaysAreEmpty() {
        let many = String(repeating: "word ", count: 400)
        let ledger = makeLedger([SpokenUtterance(date: now, text: many)])
        let today = ledger.day(on: now, calendar: calendar)
        #expect(today?.isToday == true)
        #expect(today?.wordCount == 400)
        #expect(today?.level == .full)
        #expect(today?.isFuture == false)

        // Monday-first: the rest of this week (Tue–Sun) is in the future.
        let future = ledger.weeks.last?.days.filter(\.isFuture) ?? []
        #expect(future.count == 6)
        #expect(future.allSatisfy { $0.wordCount == 0 && $0.level == .empty })
    }

    @Test func firstWeekIsInThePast() {
        let ledger = makeLedger([])
        #expect(ledger.weeks[0].days.allSatisfy { !$0.isFuture && $0.inWindow })
        #expect(ledger.weeks.last?.days.first?.isToday == true)
    }

    @Test func monthLabelsSitOnTheFirst() {
        let ledger = makeLedger([])
        #expect(ledger.monthLabels.isEmpty == false)
        // 1 August 2026 is a Saturday; with Monday-first weeks that 1st is in the
        // week starting 27 July, and must still be labelled August.
        let august = ledger.monthLabels.last { $0.name.hasPrefix("Aug") }
        #expect(august != nil)
    }

    @Test func lastSevenDaysAreOldestFirst() {
        let ledger = makeLedger([
            SpokenUtterance(date: day(2026, 8, 18), text: "a b"),
            SpokenUtterance(date: now, text: "c"),
        ])
        #expect(ledger.lastSevenDays.first?.start == calendar.startOfDay(for: day(2026, 8, 18)))
        #expect(ledger.lastSevenDays.first?.wordCount == 2)
        #expect(ledger.lastSevenDays.last?.wordCount == 1)
    }

    // MARK: - Helpers

    private func makeLedger(
        _ utterances: [SpokenUtterance],
        weekCount: Int = 53
    ) -> ActivityLedger {
        ActivityLedger(
            utterances: utterances,
            now: now,
            calendar: calendar,
            locale: locale,
            weekCount: weekCount
        )
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(
            from: DateComponents(
                calendar: calendar,
                timeZone: calendar.timeZone,
                year: year,
                month: month,
                day: day,
                hour: 12
            )
        )!
    }
}

private extension Calendar {
    static var gmtMonday: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }
}
