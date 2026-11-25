import Foundation

struct FocusStatisticsSnapshot {
  struct Bucket: Identifiable {
    let date: Date
    let seconds: TimeInterval
    var id: Date { date }
  }

  let buckets: [Bucket]
  let totalSeconds: TimeInterval
  let completedSessions: Int
  let records: [FocusSession]

  init(history: FocusHistory, period: FocusChartPeriod, calendar: Calendar = .current) {
    let intervals = period.intervals(endingAt: history.now, calendar: calendar)
    let range = DateInterval(
      start: intervals.first?.start ?? history.now,
      end: history.now.addingTimeInterval(0.001))
    buckets = intervals.map { interval in
      Bucket(date: interval.start, seconds: history.focusedSeconds(in: interval))
    }
    totalSeconds = history.focusedSeconds(in: range)
    // Capture the bounds once: deriving the chart range inside this filter rescans history per row.
    records = history.sessions.filter { $0.endedAt >= range.start && $0.endedAt <= history.now }
    completedSessions = records.filter { $0.outcome == .completed }.count
  }
}
