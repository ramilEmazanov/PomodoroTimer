import SwiftUI

struct TaskRow: View {
  @Bindable var state: InterfaceState
  let task: FocusTask
  var isSelected = false
  var showProject = true
  var backgroundColor: Color = .panel
  let select: () -> Void
  let requestDelete: (FocusTask) -> Void

  var body: some View {
    HStack(alignment: .center, spacing: 12) {
      CompletionButton(completed: task.isCompleted, label: task.title, symbolSize: 20) {
        state.editTask(task.id) { $0.isCompleted.toggle() }
      }
      Button(action: select) {
        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 8) {
            Text(task.title).font(.system(size: 15, weight: .medium))
              .strikethrough(task.isCompleted)
              .foregroundStyle(task.isCompleted ? .secondary : .primary)
              .lineLimit(1).truncationMode(.tail)
              .layoutPriority(1)
              .help(task.title)
            if showProject,
              let project = state.projects.first(where: { $0.id == task.projectID })
            {
              Label(project.title, systemImage: "folder").font(.system(size: 13))
                .foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                .frame(maxWidth: 140, alignment: .leading)
                .help(project.title)
            }
          }
          if task.isInMyDay || !task.subtasks.isEmpty || task.dueDate != nil {
            HStack(spacing: 5) {
              if task.isInMyDay {
                Label("My Day", systemImage: "sun.max")
                if !task.subtasks.isEmpty || task.dueDate != nil {
                  Text("·").accessibilityHidden(true)
                }
              }
              if !task.subtasks.isEmpty {
                Text("\(task.completedSteps) of \(task.subtasks.count)")
                if task.dueDate != nil {
                  Text("·").accessibilityHidden(true)
                }
              }
              if let date = task.dueDate {
                Label(
                  date.formatted(
                    Date.VerbatimFormatStyle(
                      format:
                        "\(weekday: .abbreviated), \(day: .defaultDigits) \(month: .abbreviated)",
                      locale: Locale(identifier: "en_US"),
                      timeZone: .current,
                      calendar: .current
                    )),
                  systemImage: "calendar"
                )
                .foregroundStyle(task.isOverdue(at: state.now) ? Color.red : .secondary)
              }
            }
            .font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Open task: \(task.title)")
      Button {
        state.editTask(task.id) { $0.isImportant.toggle() }
      } label: {
        Image(systemName: task.isImportant ? "star.fill" : "star")
          .font(.system(size: 14))
          .frame(width: 24, height: 30)
          .contentShape(Rectangle())
          .foregroundStyle(task.isImportant ? Color.blue : .secondary)
      }
      .buttonStyle(.plain)
      .help(task.isImportant ? "Remove importance" : "Mark important")
      .accessibilityLabel("\(task.isImportant ? "Unmark" : "Mark") important: \(task.title)")
    }
    .padding(.horizontal, 14).frame(height: 52)
    .background {
      Button(action: select) {
        RoundedRectangle(cornerRadius: 10)
          .fill(isSelected ? Color.blue.opacity(0.16) : backgroundColor)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityHidden(true)
    }
    .contextMenu {
      Button(task.isCompleted ? "Mark incomplete" : "Mark complete") {
        state.editTask(task.id) { $0.isCompleted.toggle() }
      }
      Button(task.isInMyDay ? "Remove from My Day" : "Add to My Day") {
        state.setMyDay(task.id, included: !task.isInMyDay)
      }
      Button("Delete task…", role: .destructive) { requestDelete(task) }
    }
  }
}
