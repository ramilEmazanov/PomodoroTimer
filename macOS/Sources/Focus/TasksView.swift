import SwiftUI

struct TasksView: View {
  @Bindable var state: InterfaceState
  var projectID: UUID? = nil
  @State private var selection: UUID?
  @State private var newTitle = ""
  @State private var sort: TaskSort = .dueDate
  @State private var showCompletedTasks = false
  @State private var showCompactDetail = false
  @State private var deletion: FocusTask?
  @FocusState private var composerFocused: Bool

  private var project: FocusProject? { state.projects.first { $0.id == projectID } }
  private var scopedTasks: [FocusTask] {
    state.tasks.filter { projectID == nil || $0.projectID == projectID }
  }

  private var activeTasks: [FocusTask] {
    sort.sorted(scopedTasks.filter { !$0.isCompleted })
  }

  private var completedTasks: [FocusTask] {
    sort.sorted(scopedTasks.filter(\.isCompleted))
  }

  private enum ListEntry: Identifiable {
    case task(FocusTask)
    case completedHeader

    enum ID: Hashable {
      // Recreate the row when it moves between active and completed tasks.
      case task(UUID, completed: Bool)
      case completedHeader
    }

    var id: ID {
      switch self {
      case .task(let task): .task(task.id, completed: task.isCompleted)
      case .completedHeader: .completedHeader
      }
    }
  }

  private var listEntries: [ListEntry] {
    var entries = activeTasks.map(ListEntry.task)
    if !completedTasks.isEmpty {
      entries.append(.completedHeader)
      if showCompletedTasks { entries += completedTasks.map(ListEntry.task) }
    }
    return entries
  }

  private var selectedTask: FocusTask? { state.tasks.first { $0.id == selection } }

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.width < 720
      HStack(spacing: 0) {
        taskList(compact: compact)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        if !compact, let task = selectedTask {
          Divider()
          detail(task)
            .frame(width: min(360, geometry.size.width * 0.42))
            .background(Color.panel)
        }
      }
      .onChange(of: compact) { _, value in if !value { showCompactDetail = false } }
      .sheet(
        isPresented: $showCompactDetail,
        onDismiss: {
          if compact { selection = nil }
        }
      ) {
        TaskDetailSheet(state: state, taskID: selection) { showCompactDetail = false }
      }
    }
    .onChange(of: state.tasks.map(\.id)) { _, ids in
      if let selection, !ids.contains(selection) {
        self.selection = nil
        showCompactDetail = false
      }
    }
    .alert(
      "Delete task?",
      isPresented: Binding(get: { deletion != nil }, set: { if !$0 { deletion = nil } }),
      presenting: deletion
    ) { task in
      Button("Cancel", role: .cancel) { deletion = nil }
      Button("Delete", role: .destructive) {
        state.deleteTask(task.id)
        deletion = nil
      }
    } message: { task in
      Text("“\(task.title)” and its subtasks and note will be deleted.")
    }
  }

  private func detail(_ task: FocusTask) -> some View {
    TaskDetailView(state: state, task: task, requestDelete: { state.deleteTask(task.id) })
      .id(task.id)
  }

  private func taskList(compact: Bool) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Text(project?.title ?? "Tasks").font(.system(size: 36, weight: .bold)).tracking(-1)
            .lineLimit(2).textSelection(.enabled)
          Spacer()
          Button {
            composerFocused = true
          } label: {
            Image(systemName: "plus").font(.system(size: 18))
          }
          .buttonStyle(.borderless).keyboardShortcut("n", modifiers: .command)
          .help("New task (⌘N)").accessibilityLabel("New task")
        }
        if let project {
          Label(
            FocusHistory.display(state.focusedSeconds(projectID: project.id)) + " focused",
            systemImage: "timer"
          )
          .font(.system(size: 16, weight: .medium)).monospacedDigit()
        }
        HStack {
          Menu {
            Picker("Sort tasks", selection: $sort) {
              ForEach(TaskSort.allCases) { Text($0.rawValue).tag($0) }
            }
          } label: {
            Label(sort.rawValue, systemImage: "arrow.up.arrow.down")
          }
          .menuStyle(.borderlessButton).fixedSize()
          Spacer(minLength: 8)
        }
        .font(.system(size: 12))
        if state.pendingTasks != nil {
          Label(
            "Task changes haven’t been saved. Use Retry storage above.",
            systemImage: "exclamationmark.triangle"
          )
          .font(.system(size: 12)).foregroundStyle(.orange)
        }
      }
      .padding(24)
      GeometryReader { listGeometry in
        ScrollView {
          LazyVStack(spacing: 5) {
            if scopedTasks.isEmpty {
              VStack(spacing: 12) {
                Image(systemName: "checklist")
                  .font(.system(size: 28, weight: .light))
                Text("Make room for what matters").font(.headline)
                Text("Add your first task below, then break it into smaller steps.")
                  .font(.callout).multilineTextAlignment(.center)
              }
              .foregroundStyle(.secondary).padding(.vertical, 48).padding(.horizontal, 16)
              .frame(maxWidth: .infinity)
            }
            ForEach(listEntries) { entry in
              switch entry {
              case .task(let task):
                taskRow(task) {
                  selection = task.id
                  if compact { showCompactDetail = true }
                }
              case .completedHeader:
                Button {
                  showCompletedTasks.toggle()
                } label: {
                  HStack(spacing: 6) {
                    Image(systemName: showCompletedTasks ? "chevron.down" : "chevron.right")
                      .font(.system(size: 10, weight: .semibold))
                      .frame(width: 12)
                    Text("Completed Tasks")
                  }
                  .font(.system(size: 12, weight: .medium))
                  .padding(.horizontal, 8).padding(.vertical, 6)
                  .background(Color.panel, in: RoundedRectangle(cornerRadius: 6))
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Color.blue)
                .accessibilityLabel("Completed Tasks")
                .accessibilityValue(
                  showCompletedTasks ? "Expanded" : "Collapsed"
                )
                .accessibilityHint("Show or hide completed tasks")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12).padding(.bottom, 4)
              }
            }
          }
          .padding(.horizontal, 24).padding(.bottom, 16)
          .frame(minHeight: listGeometry.size.height, alignment: .top)
          .background(deselectionBackground)
        }
      }
      Spacer(minLength: 0)
      HStack(spacing: 12) {
        Image(systemName: "plus").foregroundStyle(.blue)
          .frame(width: 28, height: 30)
        TextField(project == nil ? "Add a task" : "Add a task to this project", text: $newTitle)
          .textFieldStyle(.plain).focused($composerFocused)
          .onSubmit { addTask(compact: compact) }
        Button("Add") { addTask(compact: compact) }
          .buttonStyle(.borderless)
          .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .font(.system(size: 15, weight: .medium))
      .padding(.horizontal, 14).frame(height: 52)
      .background(Color.panel, in: RoundedRectangle(cornerRadius: 10))
      .padding(24)
    }
    .background(deselectionBackground)
  }

  private var deselectionBackground: some View {
    Color.clear
      .contentShape(Rectangle())
      .onTapGesture {
        selection = nil
        showCompactDetail = false
        composerFocused = false
      }
  }

  private func addTask(compact: Bool) {
    guard let id = state.addTask(title: newTitle, projectID: projectID) else { return }
    selection = id
    newTitle = ""
    if compact { showCompactDetail = true }
  }

  private func taskRow(_ task: FocusTask, select: @escaping () -> Void) -> some View {
    TaskRow(
      state: state, task: task, isSelected: selection == task.id,
      showProject: projectID == nil, select: select,
      requestDelete: { deletion = $0 }
    )
  }

}

struct CompletionButton: View {
  let completed: Bool
  let label: String
  var small = false
  var symbolSize: CGFloat = 23
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Group {
        if completed {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.blue)
        } else {
          Image(systemName: "circle")
            .foregroundStyle(.secondary)
        }
      }
      .font(.system(size: small ? 19 : symbolSize, weight: .regular))
      .frame(width: small ? 24 : 28, height: 30)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(completed ? "Mark incomplete" : "Complete"): \(label)")
    .accessibilityValue(completed ? "Completed" : "Incomplete")
  }
}
