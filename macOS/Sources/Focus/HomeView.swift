import SwiftUI

struct HomeView: View {
  @Bindable var state: InterfaceState
  private let tasks: [(String, Bool, String)] = [
    ("Outline the presentation", true, "45 min"),
    ("Review incoming messages", true, "25 min"),
    ("Update the project plan", true, "35 min"),
    ("Review interface designs", false, "25 min"),
    ("Reflect on the day", false, "15 min"),
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      VStack(alignment: .leading, spacing: 12) {
        PageHeading(title: "Home")
        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
          .font(.system(size: 13)).foregroundStyle(.secondary)
      }
      if state.emptyHome {
        EmptyPanel(
          symbol: "scope", title: "Start your first session",
          message: "Your focus time and completed tasks will appear here."
        ) { state.section = .timer }
      } else {
        ViewThatFits(in: .horizontal) {
          HStack(spacing: 14) { metrics }
          VStack(spacing: 14) { metrics }
        }
        Surface {
          VStack(alignment: .leading, spacing: 24) {
            HStack {
              VStack(alignment: .leading, spacing: 6) {
                Text("Today’s tasks").font(.system(size: 20, weight: .semibold))
                Text("3 of 5 completed").font(.system(size: 13)).foregroundStyle(.secondary)
              }
              Spacer()
              Button("Start Focus") { state.section = .timer }.buttonStyle(ActionStyle())
            }
            VStack(spacing: 0) {
              ForEach(tasks.indices, id: \.self) { index in
                let task = tasks[index]
                HStack(spacing: 14) {
                  Image(systemName: task.1 ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20)).foregroundStyle(task.1 ? Color.blue : Color.secondary)
                  Text(task.0).strikethrough(task.1).foregroundStyle(task.1 ? .secondary : .primary)
                  Spacer(minLength: 12)
                  Text(task.2).font(.system(size: 13)).foregroundStyle(.secondary)
                }
                .frame(minHeight: 56)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(task.0), \(task.1 ? "completed" : "incomplete"), \(task.2)")
                if index < tasks.count - 1 { Divider().opacity(0.5) }
              }
            }
          }
        }
        Text("Sample tasks and focus totals").font(.system(size: 11)).foregroundStyle(.secondary)
      }
    }
  }

  @ViewBuilder private var metrics: some View {
    metric("Focus today", "1 h 45 min", "18 min more than yesterday", accent: true)
    metric("Focus this week", "8 h 20 min", "12% more than last week")
    metric("Sessions completed", "4", "Your best this week")
  }

  private func metric(_ title: String, _ value: String, _ note: String, accent: Bool = false)
    -> some View
  {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
      Text(value).font(.system(size: 25, weight: .semibold)).tracking(-0.5)
      Text(note).font(.system(size: 11)).foregroundStyle(.secondary)
    }
    .frame(minWidth: 155, maxWidth: .infinity, minHeight: 100, alignment: .leading)
    .padding(20)
    .background(
      accent ? Color(light: 0xEDF6FF, dark: 0x233243) : Color.panel,
      in: RoundedRectangle(cornerRadius: 22))
  }
}
