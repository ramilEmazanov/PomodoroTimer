import SwiftUI

struct StatisticsSummary: View {
  let state: InterfaceState

  private var today: DateInterval {
    Calendar.current.dateInterval(of: .day, for: state.now)!
  }

  private var week: DateInterval {
    Calendar.current.dateInterval(of: .weekOfYear, for: state.now)!
  }

  var body: some View {
    VStack(spacing: 14) {
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 14) { focusCards }
        VStack(spacing: 14) { focusCards }
      }
      ViewThatFits(in: .horizontal) {
        HStack(spacing: 14) { taskCards }
        VStack(spacing: 14) { taskCards }
      }
    }
  }

  @ViewBuilder private var focusCards: some View {
    timeCard(
      "Total Focus Time",
      seconds: state.history.focusedSeconds(in: DateInterval(start: .distantPast, end: state.now)))
    timeCard("Focus Time of This Week", seconds: state.history.focusedSeconds(in: week))
    timeCard("Focus Time of Today", seconds: state.history.focusedSeconds(in: today))
  }

  @ViewBuilder private var taskCards: some View {
    taskCard("Total Completed Tasks", count: state.completedTaskCount())
    taskCard("Tasks Completed This Week", count: state.completedTaskCount(in: week))
    taskCard("Tasks Completed Today", count: state.completedTaskCount(in: today))
  }

  private func taskCard(_ title: String, count: Int) -> some View {
    SummaryMetric(title: title, value: "\(count)", markerColor: .primary, compact: true)
  }

  private func timeCard(_ title: String, seconds: TimeInterval) -> some View {
    SummaryMetric(
      title: title, value: FocusHistory.display(seconds), markerColor: .blue, compact: true)
  }
}
