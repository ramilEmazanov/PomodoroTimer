import Charts
import SwiftUI

struct StatisticsView: View {
  let state: InterfaceState
  @State private var period: FocusChartPeriod = .daily
  @State private var pageSize = 20

  private struct ProjectFocus: Identifiable {
    let project: FocusProject
    let seconds: TimeInterval
    var id: UUID { project.id }
  }

  private var projectFocus: [ProjectFocus] {
    state.projects.map { project in
      ProjectFocus(project: project, seconds: state.focusedSeconds(projectID: project.id))
    }
    .sorted { left, right in
      if left.seconds != right.seconds { return left.seconds > right.seconds }
      let comparison = left.project.title.localizedStandardCompare(right.project.title)
      if comparison != .orderedSame { return comparison == .orderedAscending }
      return left.id.uuidString < right.id.uuidString
    }
  }

  private var axisFormat: Date.FormatStyle {
    switch period {
    case .daily, .weekly: .dateTime.day().month(.abbreviated)
    case .monthly: .dateTime.month(.abbreviated)
    case .yearly: .dateTime.year()
    }
  }

  private var chartUnit: String { period == .daily ? "Minutes" : "Hours" }
  private var secondsPerUnit: Double { period == .daily ? 60 : 3600 }

  var body: some View {
    let snapshot = FocusStatisticsSnapshot(history: state.history, period: period)
    VStack(alignment: .leading, spacing: 24) {
      PageHeading(
        title: "Statistics", subtitle: "Your focus time, session history and daily progress.")
      StatisticsSummary(state: state)
      Surface {
        VStack(alignment: .leading, spacing: 22) {
          ViewThatFits(in: .horizontal) {
            HStack {
              Text("Focus Time Chart").font(.system(size: 20, weight: .semibold))
              Spacer()
              periodPicker.frame(width: 300)
            }
            VStack(alignment: .leading, spacing: 12) {
              Text("Focus Time Chart").font(.system(size: 20, weight: .semibold))
              periodPicker.frame(maxWidth: 360)
            }
          }
          Text(period.rangeLabel).font(.system(size: 12)).foregroundStyle(.secondary)
          HStack(spacing: 24) {
            Text(FocusHistory.display(snapshot.totalSeconds))
              .font(.system(size: 28, weight: .semibold)).monospacedDigit()
            Text("\(snapshot.completedSessions) completed sessions").foregroundStyle(
              .secondary)
          }
          Chart(snapshot.buckets) { bucket in
            BarMark(
              x: .value("Period", bucket.date, unit: period.component),
              y: .value(chartUnit, bucket.seconds / secondsPerUnit)
            )
            .foregroundStyle(.blue).cornerRadius(4)
            .accessibilityLabel(bucket.date.formatted(date: .abbreviated, time: .omitted))
            .accessibilityValue(FocusHistory.display(bucket.seconds))
          }
          .chartYScale(
            domain: 0...max(1, (snapshot.buckets.map(\.seconds).max() ?? 0) / secondsPerUnit * 1.1)
          )
          .chartYAxisLabel(chartUnit)
          .chartXAxis {
            AxisMarks(values: snapshot.buckets.map(\.date)) { _ in
              AxisValueLabel(format: axisFormat)
            }
          }
          .frame(height: 230)
          Text(
            "Pauses are excluded. Time across midnight is split between days. Running and interrupted sessions count toward focus time."
          )
          .font(.system(size: 12)).foregroundStyle(.secondary)
        }
      }
      projectsFocus
      Surface {
        VStack(alignment: .leading, spacing: 16) {
          Text("Session history").font(.system(size: 20, weight: .semibold))
          if snapshot.records.isEmpty {
            Text("No sessions in this period. Start a timer to begin tracking your focus.")
              .foregroundStyle(.secondary)
          } else {
            SessionHistoryList(sessions: Array(snapshot.records.prefix(pageSize)))
            if snapshot.records.count > pageSize {
              Button("Show more sessions") { pageSize += 20 }.buttonStyle(
                ActionStyle(prominent: false))
            }
          }
        }
      }
    }
  }

  private var periodPicker: some View {
    Picker("Period", selection: $period) {
      ForEach(FocusChartPeriod.allCases) { Text($0.rawValue).tag($0) }
    }
    .pickerStyle(.segmented)
    .onChange(of: period) { _, _ in pageSize = 20 }
  }

  private var projectsFocus: some View {
    Surface {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text("Projects Focus").font(.system(size: 20, weight: .semibold))
          Spacer()
          Text("All time").font(.system(size: 12)).foregroundStyle(.secondary)
        }
        if state.projects.isEmpty {
          Text("Create a project and focus on its tasks to see time spent here.")
            .font(.system(size: 14)).foregroundStyle(.secondary)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(projectFocus.enumerated()), id: \.element.id) { index, total in
              if index > 0 { Divider() }
              HStack(spacing: 12) {
                Image(systemName: "folder").foregroundStyle(.blue)
                  .frame(width: 24)
                Text(total.project.title).font(.system(size: 20, weight: .medium))
                  .lineLimit(2).help(total.project.title)
                Spacer(minLength: 16)
                Text(FocusHistory.display(total.seconds))
                  .font(.system(size: 20, weight: .medium)).monospacedDigit().fixedSize()
              }
              .padding(.vertical, 12)
              .accessibilityElement(children: .combine)
            }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
