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

  private var selectedTask: FocusTask? { state.tasks.first { $0.id == selection } }

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.width < 720
      HStack(spacing: 0) {
        taskList(compact: compact)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        if !compact {
          Divider()
          Group {
            if let task = selectedTask {
              detail(task)
            } else {
              VStack(spacing: 12) {
                Image(systemName: "checklist").font(.system(size: 34, weight: .light))
                Text("Select a task").font(.headline)
                Text("Its steps, due date and note will appear here.")
                  .font(.callout).multilineTextAlignment(.center)
              }
              .foregroundStyle(.secondary).padding(28)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
          }
          .frame(width: min(360, geometry.size.width * 0.42))
          .background(Color.panel)
        }
      }
      .onChange(of: compact) { _, value in if !value { showCompactDetail = false } }
      .sheet(isPresented: $showCompactDetail) {
        VStack(spacing: 0) {
          HStack {
            Text("Task details").font(.headline)
            Spacer()
            Button("Done") { showCompactDetail = false }.keyboardShortcut(.cancelAction)
          }
          .padding(20)
          Divider()
          if let task = selectedTask { detail(task) }
        }
        .frame(width: 440, height: 640)
        .background(Color.panel)
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
        Text(
          "\(scopedTasks.filter { !$0.isCompleted }.count) active · \(scopedTasks.filter(\.isCompleted).count) completed"
        )
        .font(.system(size: 12)).foregroundStyle(.secondary)
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
          ForEach(activeTasks) { task in
            taskRow(task) {
              selection = task.id
              if compact { showCompactDetail = true }
            }
          }
          if !completedTasks.isEmpty {
            Button {
              showCompletedTasks.toggle()
            } label: {
              HStack(spacing: 6) {
                Image(systemName: showCompletedTasks ? "chevron.down" : "chevron.right")
                  .font(.system(size: 10, weight: .semibold))
                  .frame(width: 12)
                Text("Completed Tasks")
                Text("\(completedTasks.count)").foregroundStyle(.secondary)
              }
              .font(.system(size: 12, weight: .medium))
              .padding(.horizontal, 8).padding(.vertical, 6)
              .background(Color.panel, in: RoundedRectangle(cornerRadius: 6))
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(Color.blue)
            .accessibilityLabel("Completed Tasks")
            .accessibilityValue(
              "\(completedTasks.count) tasks, \(showCompletedTasks ? "expanded" : "collapsed")"
            )
            .accessibilityHint("Show or hide completed tasks")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12).padding(.bottom, 4)

            if showCompletedTasks {
              ForEach(completedTasks) { task in
                taskRow(task) {
                  selection = task.id
                  if compact { showCompactDetail = true }
                }
              }
            }
          }
        }
        .padding(.horizontal, 24).padding(.bottom, 16)
      }
      Spacer(minLength: 0)
      HStack(spacing: 10) {
        Image(systemName: "plus").foregroundStyle(.blue)
        TextField(project == nil ? "Add a task" : "Add a task to this project", text: $newTitle)
          .textFieldStyle(.plain).focused($composerFocused)
          .onSubmit { addTask(compact: compact) }
        Button("Add") { addTask(compact: compact) }
          .buttonStyle(.borderless)
          .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .padding(14).background(Color.panel, in: RoundedRectangle(cornerRadius: 12))
      .padding(24)
    }
  }

  private func addTask(compact: Bool) {
    guard let id = state.addTask(title: newTitle, projectID: projectID) else { return }
    selection = id
    newTitle = ""
    if compact { showCompactDetail = true }
  }

  private func taskRow(_ task: FocusTask, select: @escaping () -> Void) -> some View {
    HStack(alignment: .center, spacing: 12) {
      CompletionButton(completed: task.isCompleted, label: task.title) {
        state.editTask(task.id) { $0.isCompleted.toggle() }
      }
      Button {
        state.prepareTimer(for: task.id)
      } label: {
        Image(systemName: state.saved.active?.assignment?.taskID == task.id ? "timer" : "play.fill")
          .font(.system(size: 12)).foregroundStyle(.blue)
          .frame(width: 28, height: 30).contentShape(Rectangle())
      }
      .buttonStyle(.plain).disabled(state.saved.active != nil)
      .help("Set timer for this task").accessibilityLabel("Set timer for \(task.title)")
      Button(action: select) {
        VStack(alignment: .leading, spacing: 3) {
          Text(task.title).font(.system(size: 15, weight: .medium))
            .strikethrough(task.isCompleted)
            .foregroundStyle(task.isCompleted ? .secondary : .primary)
            .lineLimit(2).multilineTextAlignment(.leading)
          Text(FocusHistory.display(state.focusedSeconds(taskID: task.id)) + " focused")
            .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
          if projectID == nil,
            let project = state.projects.first(where: { $0.id == task.projectID })
          {
            Label(project.title, systemImage: "folder").font(.system(size: 11))
              .foregroundStyle(.secondary).lineLimit(1)
          }
          if !task.subtasks.isEmpty || task.dueDate != nil || !task.note.isEmpty {
            HStack(spacing: 8) {
              if !task.subtasks.isEmpty {
                Text("\(task.completedSteps) of \(task.subtasks.count)")
              }
              if let date = task.dueDate {
                Label(date.formatted(.dateTime.day().month(.abbreviated)), systemImage: "calendar")
                  .foregroundStyle(task.isOverdue(at: state.now) ? Color.red : .secondary)
              }
              if !task.note.isEmpty {
                Image(systemName: "note.text").accessibilityLabel("Has a note")
              }
            }
            .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
          }
        }
        .frame(maxWidth: .infinity, minHeight: 30, alignment: .leading)
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
    .padding(.horizontal, 14).padding(.vertical, 6)
    .background(
      selection == task.id ? Color.blue.opacity(0.16) : Color.panel,
      in: RoundedRectangle(cornerRadius: 10)
    )
    .contextMenu {
      Button(task.isCompleted ? "Mark incomplete" : "Mark complete") {
        state.editTask(task.id) { $0.isCompleted.toggle() }
      }
      Button("Delete task…", role: .destructive) { deletion = task }
    }
  }
}

struct CompletionButton: View {
  let completed: Bool
  let label: String
  var small = false
  let action: () -> Void
  var body: some View {
    Button(action: action) {
      Image(systemName: completed ? "checkmark.circle.fill" : "circle")
        .font(.system(size: small ? 19 : 23, weight: .regular))
        .foregroundStyle(completed ? Color.blue : .secondary)
        .frame(width: small ? 24 : 28, height: 30)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(completed ? "Mark incomplete" : "Complete"): \(label)")
    .accessibilityValue(completed ? "Completed" : "Incomplete")
  }
}
