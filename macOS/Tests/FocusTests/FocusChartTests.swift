import Foundation
import Testing

@testable import Focus

@MainActor
struct FocusChartTests {
  @Test(arguments: FocusChartPeriod.allCases)
  func sessionsSplitAcrossCalendarBoundaries(_ period: FocusChartPeriod) throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    calendar.firstWeekday = 2
    calendar.minimumDaysInFirstWeek = 4
    let now = try #require(
      calendar.date(from: DateComponents(year: 2024, month: 3, day: 11, hour: 12)))
    let current = try #require(calendar.dateInterval(of: period.component, for: now))
    let start = current.start.addingTimeInterval(-1800)
    let end = current.start.addingTimeInterval(1800)
    let session = FocusSession(
      id: UUID(), startedAt: start, endedAt: end, plannedSeconds: 3600, outcome: .completed,
      intervals: [FocusInterval(start: start, end: end)])
    let history = FocusHistory(sessions: [session], active: nil, now: now)
    let intervals = period.intervals(endingAt: now, calendar: calendar)
    let seconds = intervals.map { history.focusedSeconds(in: $0) }
    #expect(Array(seconds.suffix(2)) == [1800, 1800])
    #expect(seconds.reduce(0, +) == 3600)
    for (previous, next) in zip(intervals, intervals.dropFirst()) {
      #expect(previous.end == next.start)
    }
  }

  @Test func dailyIntervalsFollowDaylightSavingTime() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let now = try #require(
      calendar.date(from: DateComponents(year: 2024, month: 3, day: 10, hour: 12)))
    let intervals = FocusChartPeriod.daily.intervals(endingAt: now, calendar: calendar)
    let duration = try #require(intervals.last?.duration)
    #expect(abs(duration - 23 * 3600) < 0.001)
    #expect(intervals.dropLast().last?.end == intervals.last?.start)
  }
}
