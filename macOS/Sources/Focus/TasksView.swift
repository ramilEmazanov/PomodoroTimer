import SwiftUI

struct TasksView: View {
  @Bindable var state: InterfaceState
  @State private var selection: UUID?
  @State private var newTitle = ""
  @State private var search = ""
  @State private var sort: TaskSort = .dueDate
  @State private var filter: TaskFilter = .all
  @State private var showCompactDetail = false
  @State private var deletion: FocusTask?
  @FocusState private var composerFocused: Bool

  private enum TaskFilter: String, CaseIterable, Identifiable {
    case all = "All tasks"
    case active = "Active"
    case completed = "Completed"
    var id: Self { self }
  }

  private var visibleTasks: [FocusTask] {
    sort.sorted(
      state.tasks.filter { task in
        let matchesFilter =
          switch filter {
          case .all: true
          case .active: !task.isCompleted
          case .completed: task.isCompleted
          }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesSearch =
          query.isEmpty
          || ([task.title, task.note] + task.subtasks.map(\.title))
            .contains { $0.localizedStandardContains(query) }
        return matchesFilter && matchesSearch
      })
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
          Text("Tasks").font(.system(size: 36, weight: .bold)).tracking(-1)
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
          "\(state.tasks.filter { !$0.isCompleted }.count) active · \(state.tasks.filter(\.isCompleted).count) completed"
        )
        .font(.system(size: 12)).foregroundStyle(.secondary)
        HStack(spacing: 8) {
          Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
          TextField("Search tasks", text: $search).textFieldStyle(.plain)
          if !search.isEmpty {
            Button {
              search = ""
            } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
            }
            .buttonStyle(.plain).accessibilityLabel("Clear search")
          }
        }
        .padding(10).background(Color.panel, in: RoundedRectangle(cornerRadius: 9))
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
          Picker("Show tasks", selection: $filter) {
            ForEach(TaskFilter.allCases) { Text($0.rawValue).tag($0) }
          }
          .labelsHidden().pickerStyle(.menu).fixedSize()
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
          if visibleTasks.isEmpty {
            VStack(spacing: 12) {
              Image(systemName: state.tasks.isEmpty ? "checklist" : "magnifyingglass")
                .font(.system(size: 28, weight: .light))
              Text(state.tasks.isEmpty ? "Make room for what matters" : "No matching tasks").font(
                .headline)
              Text(
                state.tasks.isEmpty
                  ? "Add your first task below, then break it into smaller steps."
                  : "Try another search or task filter."
              )
              .font(.callout).multilineTextAlignment(.center)
            }
            .foregroundStyle(.secondary).padding(.vertical, 48).padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
          }
          ForEach(visibleTasks) { task in
            taskRow(task) {
              selection = task.id
              if compact { showCompactDetail = true }
            }
          }
        }
        .padding(.horizontal, 24).padding(.bottom, 16)
      }
      Spacer(minLength: 0)
      HStack(spacing: 10) {
        Image(systemName: "plus").foregroundStyle(.blue)
        TextField("Add a task", text: $newTitle)
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
    guard let id = state.addTask(title: newTitle) else { return }
    selection = id
    newTitle = ""
    search = ""
    filter = .all
    if compact { showCompactDetail = true }
  }

  private func taskRow(_ task: FocusTask, select: @escaping () -> Void) -> some View {
    HStack(spacing: 12) {
      CompletionButton(completed: task.isCompleted, label: task.title) {
        state.editTask(task.id) { $0.isCompleted.toggle() }
      }
      Button(action: select) {
        VStack(alignment: .leading, spacing: 6) {
          Text(task.title).font(.system(size: 15, weight: .medium))
            .strikethrough(task.isCompleted)
            .foregroundStyle(task.isCompleted ? .secondary : .primary)
            .lineLimit(2).multilineTextAlignment(.leading)
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
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Open task: \(task.title)")
      Button {
        state.editTask(task.id) { $0.isImportant.toggle() }
      } label: {
        Image(systemName: task.isImportant ? "star.fill" : "star")
          .foregroundStyle(task.isImportant ? Color.blue : .secondary)
      }
      .buttonStyle(.plain)
      .help(task.isImportant ? "Remove importance" : "Mark important")
      .accessibilityLabel("\(task.isImportant ? "Unmark" : "Mark") important: \(task.title)")
    }
    .padding(.horizontal, 14).padding(.vertical, 10)
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
