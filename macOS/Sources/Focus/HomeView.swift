import SwiftUI

struct HomeView: View {
  @Bindable var state: InterfaceState

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 12) {
        PageHeading(title: "Home")
        Text(state.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
          .font(.system(size: 13)).foregroundStyle(.secondary)
      }
      if state.sessions.isEmpty && state.saved.active == nil {
        EmptyPanel(
          symbol: "scope", title: "Start your first session",
          message: "Your focus time and completed sessions will appear here."
        ) { state.section = .timer }
      } else {
        FocusSummary(state: state)
        Surface {
          VStack(alignment: .leading, spacing: 0) {
            HStack {
              Text("Recent sessions").font(.system(size: 20, weight: .semibold))
              Spacer()
              Button(state.saved.active == nil ? "Start Focus" : "Open timer") {
                state.section = .timer
              }
              .buttonStyle(ActionStyle())
            }
            if state.saved.active != nil {
              Label(
                state.phase == .paused ? "Your session is paused" : "A focus session is running",
                systemImage: "timer"
              )
              .foregroundStyle(.secondary)
            }
            if state.sessions.isEmpty {
              Text("Completed and interrupted sessions will appear here.").foregroundStyle(
                .secondary)
            } else {
              SessionHistoryList(sessions: Array(state.sessions.prefix(5)))
            }
          }
        }
      }
    }
  }
}

struct FocusSummary: View {
  let state: InterfaceState
  private var today: DateInterval { Calendar.current.dateInterval(of: .day, for: state.now)! }
  private var week: DateInterval { Calendar.current.dateInterval(of: .weekOfYear, for: state.now)! }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 14) { metrics }
      VStack(spacing: 14) { metrics }
    }
  }

  @ViewBuilder private var metrics: some View {
    metric(
      "Focus today", FocusHistory.display(state.history.focusedSeconds(in: today)),
      "Actual time, excluding pauses", accent: true)
    metric(
      "Focus this week", FocusHistory.display(state.history.focusedSeconds(in: week)),
      "Includes interrupted sessions")
    metric("Sessions completed", "\(state.history.completed(in: today))", "Completed today")
  }

  private func metric(_ title: String, _ value: String, _ note: String, accent: Bool = false)
    -> some View
  {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
      Text(value).font(.system(size: 25, weight: .semibold)).tracking(-0.5).monospacedDigit()
      Text(note).font(.system(size: 11)).foregroundStyle(.secondary)
    }
    .frame(minWidth: 155, maxWidth: .infinity, minHeight: 100, alignment: .leading)
    .padding(20)
    .background(
      accent ? Color(light: 0xEDF6FF, dark: 0x233243) : Color.panel,
      in: RoundedRectangle(cornerRadius: 22))
  }
}

struct SessionHistoryList: View {
  let sessions: [FocusSession]
  var body: some View {
    VStack(spacing: 0) {
      ForEach(sessions) { session in
        HStack(spacing: 14) {
          Image(systemName: session.outcome == .completed ? "checkmark.circle.fill" : "stop.circle")
            .font(.system(size: 22)).foregroundStyle(
              session.outcome == .completed ? .green : .secondary)
          VStack(alignment: .leading, spacing: 5) {
            Text(session.outcome == .completed ? "Focus completed" : "Session interrupted").font(
              .system(size: 14, weight: .medium))
            if let assignment = session.assignment {
              Text(assignment.taskTitle).font(.system(size: 13)).lineLimit(2)
              if let project = assignment.projectTitle {
                Label(project, systemImage: "folder").font(.system(size: 11))
                  .foregroundStyle(.secondary).lineLimit(1)
              }
            }
            Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
              .font(.system(size: 12)).foregroundStyle(.secondary)
          }
          Spacer(minLength: 12)
          VStack(alignment: .trailing, spacing: 5) {
            Text(FocusHistory.display(session.focusedSeconds)).monospacedDigit()
            Text("of \(InterfaceState.durationLabel(session.plannedSeconds))").font(
              .system(size: 11)
            ).foregroundStyle(.secondary)
          }
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
        Divider()
      }
    }
  }
}
