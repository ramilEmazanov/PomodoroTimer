import Foundation
import Testing

@testable import Focus

@MainActor
struct StatisticsSnapshotTests {
  @Test(arguments: FocusChartPeriod.allCases)
  func largeHistoryPreservesChartTotalsAndPagination(_ period: FocusChartPeriod) throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let sessions = (0..<10_000).map { index in
      let end = now.addingTimeInterval(-Double(index * 600))
      return FocusSession(
        id: UUID(), startedAt: end.addingTimeInterval(-300), endedAt: end,
        plannedSeconds: 600, outcome: index.isMultiple(of: 2) ? .completed : .cancelled,
        intervals: [FocusInterval(start: end.addingTimeInterval(-300), end: end)])
    }
    let history = FocusHistory(sessions: sessions, active: nil, now: now)
    let intervals = period.intervals(endingAt: now)
    let range = DateInterval(
      start: try #require(intervals.first?.start), end: now.addingTimeInterval(0.001))
    let snapshot = FocusStatisticsSnapshot(history: history, period: period)
    #expect(snapshot.totalSeconds == history.focusedSeconds(in: range))
    #expect(snapshot.buckets.map(\.seconds) == intervals.map { history.focusedSeconds(in: $0) })
    let expected = sessions.filter { $0.endedAt >= range.start && $0.endedAt <= now }
    #expect(snapshot.records.map(\.id) == expected.map(\.id))
    #expect(snapshot.completedSessions == expected.filter { $0.outcome == .completed }.count)
    #expect(snapshot.records.prefix(20).map(\.id) == expected.prefix(20).map(\.id))
  }

  @Test func snapshotIncludesRunningFocusWithoutAddingUnfinishedSessionToHistory() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let active = ActiveSession(
      id: UUID(), startedAt: now.addingTimeInterval(-30), plannedSeconds: 60,
      runningSince: now.addingTimeInterval(-30))
    let snapshot = FocusStatisticsSnapshot(
      history: FocusHistory(sessions: [], active: active, now: now), period: .daily)
    #expect(snapshot.totalSeconds == 30)
    #expect(snapshot.buckets.reduce(0) { $0 + $1.seconds } == 30)
    #expect(snapshot.records.isEmpty)
    #expect(snapshot.completedSessions == 0)
  }
}
