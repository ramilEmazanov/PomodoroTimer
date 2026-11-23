import Charts
import SwiftUI

struct StatisticsView: View {
  let state: InterfaceState
  @State private var days = 7
  @State private var pageSize = 20

  private struct Day: Identifiable {
    let date: Date
    let seconds: TimeInterval
    var id: Date { date }
  }

  private var buckets: [Day] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: state.now)
    return (0..<days).reversed().compactMap { offset in
      guard let date = calendar.date(byAdding: .day, value: -offset, to: today),
        let interval = calendar.dateInterval(of: .day, for: date)
      else { return nil }
      return Day(date: date, seconds: state.history.focusedSeconds(in: interval))
    }
  }

  private var range: DateInterval {
    DateInterval(start: buckets.first?.date ?? state.now, end: state.now.addingTimeInterval(0.001))
  }

  private var records: [FocusSession] {
    state.sessions.filter { $0.endedAt >= range.start && $0.endedAt <= state.now }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      PageHeading(
        title: "Statistics", subtitle: "Your focus time, session history and daily progress.")
      FocusSummary(state: state)
      Surface {
        VStack(alignment: .leading, spacing: 22) {
          HStack {
            Text("Daily focus").font(.system(size: 20, weight: .semibold))
            Spacer()
            Picker("Period", selection: $days) {
              Text("7 days").tag(7)
              Text("30 days").tag(30)
            }
            .pickerStyle(.segmented).frame(width: 180)
            .onChange(of: days) { _, _ in pageSize = 20 }
          }
          HStack(spacing: 24) {
            Text(FocusHistory.display(state.history.focusedSeconds(in: range)))
              .font(.system(size: 28, weight: .semibold)).monospacedDigit()
            Text("\(state.history.completed(in: range)) completed sessions").foregroundStyle(
              .secondary)
          }
          Chart(buckets) { day in
            BarMark(x: .value("Day", day.date, unit: .day), y: .value("Minutes", day.seconds / 60))
              .foregroundStyle(.blue).cornerRadius(4)
              .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
              .accessibilityValue(FocusHistory.display(day.seconds))
          }
          .chartYScale(domain: 0...max(1, (buckets.map(\.seconds).max() ?? 0) / 60 * 1.1))
          .chartYAxisLabel("Minutes")
          .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: days == 7 ? 1 : 5)) { _ in
              AxisValueLabel(format: .dateTime.day().month(.abbreviated))
            }
          }
          .frame(height: 230)
          Text(
            "Pauses are excluded. Time across midnight is split between days. Running and interrupted sessions count toward focus time."
          )
          .font(.system(size: 12)).foregroundStyle(.secondary)
        }
      }
      Surface {
        VStack(alignment: .leading, spacing: 16) {
          Text("Session history").font(.system(size: 20, weight: .semibold))
          if records.isEmpty {
            Text("No sessions in this period. Start a timer to begin tracking your focus.")
              .foregroundStyle(.secondary)
          } else {
            SessionHistoryList(sessions: Array(records.prefix(pageSize)))
            if records.count > pageSize {
              Button("Show more sessions") { pageSize += 20 }.buttonStyle(
                ActionStyle(prominent: false))
            }
          }
        }
      }
    }
  }
}
