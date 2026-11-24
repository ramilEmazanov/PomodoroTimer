import SwiftUI

struct TaskDetailView: View {
  @Bindable var state: InterfaceState
  let task: FocusTask
  let requestDelete: () -> Void
  @State private var newStep = ""
  @State private var confirmDeletion = false
  @FocusState private var stepFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          HStack(alignment: .top, spacing: 12) {
            CompletionButton(completed: task.isCompleted, label: task.title) {
              state.editTask(task.id) { $0.isCompleted.toggle() }
            }
            EditableTaskTitle(
              title: task.title, completed: task.isCompleted,
              font: .system(size: 24, weight: .semibold), label: "Task title"
            ) { title in
              state.editTask(task.id) { $0.title = title }
            }
            Button {
              state.editTask(task.id) { $0.isImportant.toggle() }
            } label: {
              Image(systemName: task.isImportant ? "star.fill" : "star")
                .font(.system(size: 19)).foregroundStyle(task.isImportant ? Color.blue : .secondary)
            }
            .buttonStyle(.plain).help(task.isImportant ? "Remove importance" : "Mark important")
            .accessibilityLabel(task.isImportant ? "Remove importance" : "Mark important")
          }
          VStack(alignment: .leading, spacing: 12) {
            Label(
              FocusHistory.display(state.focusedSeconds(taskID: task.id)) + " focused",
              systemImage: "timer"
            )
            .font(.system(size: 18, weight: .medium)).monospacedDigit()
            Button("Set timer for this task") { state.prepareTimer(for: task.id) }
              .buttonStyle(.borderless).disabled(state.saved.active != nil || task.isCompleted)
            Picker(
              "Project",
              selection: Binding(
                get: { task.projectID },
                set: { value in state.editTask(task.id) { $0.projectID = value } }
              )
            ) {
              Text("No project").tag(nil as UUID?)
              ForEach(state.projects) { project in
                Text(project.title).tag(Optional(project.id))
              }
            }
          }
          Divider()
          VStack(alignment: .leading, spacing: 12) {
            ForEach(task.subtasks) { subtask in
              HStack(alignment: .top, spacing: 10) {
                CompletionButton(completed: subtask.isCompleted, label: subtask.title, small: true)
                {
                  state.editSubtask(subtask.id, in: task.id) { $0.isCompleted.toggle() }
                }
                EditableTaskTitle(
                  title: subtask.title, completed: subtask.isCompleted, font: .system(size: 16),
                  label: "Subtask title"
                ) { title in
                  state.editSubtask(subtask.id, in: task.id) { $0.title = title }
                }
                .padding(.top, 5)
                Menu {
                  Button("Delete subtask", role: .destructive) {
                    state.editTask(task.id) { $0.subtasks.removeAll { $0.id == subtask.id } }
                  }
                } label: {
                  Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .accessibilityLabel("Actions for \(subtask.title)").padding(.top, 5)
              }
            }
            HStack(spacing: 10) {
              Image(systemName: "plus").font(.system(size: 18)).foregroundStyle(.blue).frame(
                width: 24)
              TextField("Next step", text: $newStep).textFieldStyle(.plain)
                .focused($stepFocused).onSubmit(addStep)
              if !newStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: addStep) { Image(systemName: "arrow.turn.down.left") }
                  .buttonStyle(.borderless).accessibilityLabel("Add subtask")
              }
            }
            .padding(.vertical, 8)
            if !task.subtasks.isEmpty {
              Text("\(task.completedSteps) of \(task.subtasks.count) steps completed")
                .font(.system(size: 13)).foregroundStyle(.secondary)
            }
          }
          Divider()
          VStack(alignment: .leading, spacing: 14) {
            if let date = task.dueDate {
              HStack {
                Label("Due date", systemImage: "calendar").font(.system(size: 15, weight: .medium))
                DatePicker(
                  "Due date",
                  selection: Binding(
                    get: { date },
                    set: { value in
                      state.editTask(task.id) {
                        $0.dueDate = Calendar.current.startOfDay(for: value)
                      }
                    }), displayedComponents: .date
                )
                .labelsHidden().datePickerStyle(.field).fixedSize()
                Spacer()
                Button {
                  state.editTask(task.id) { $0.dueDate = nil }
                } label: {
                  Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain).help("Remove due date").accessibilityLabel("Remove due date")
              }
              if task.isOverdue(at: state.now) {
                Label("Overdue", systemImage: "exclamationmark.circle").font(.system(size: 14))
                  .foregroundStyle(.red)
              }
            } else {
              Button {
                state.editTask(task.id) { $0.dueDate = Calendar.current.startOfDay(for: state.now) }
              } label: {
                Label("Add due date", systemImage: "calendar.badge.plus")
              }
              .buttonStyle(.borderless)
            }
          }
          Divider()
          VStack(alignment: .leading, spacing: 12) {
            Label("Note", systemImage: "note.text").font(.system(size: 15, weight: .medium))
              .foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
              if task.note.isEmpty {
                Text("Add a note…").foregroundStyle(.tertiary).padding(.leading, 5)
                  .font(.system(size: 16))
                  .allowsHitTesting(false)
              }
              TextEditor(
                text: Binding(
                  get: { task.note }, set: { value in state.editTask(task.id) { $0.note = value } })
              )
              .font(.system(size: 16)).scrollContentBackground(.hidden)
              .frame(minHeight: 180).accessibilityLabel("Task note")
            }
          }
        }
        .padding(24)
      }
      Divider()
      HStack(spacing: 12) {
        Text("Created \(task.createdAt.formatted(date: .abbreviated, time: .omitted))")
          .font(.system(size: 13)).foregroundStyle(.secondary)
        Spacer()
        Button(role: .destructive, action: { confirmDeletion = true }) {
          Image(systemName: "trash")
        }
        .buttonStyle(.borderless).help("Delete task").accessibilityLabel("Delete task")
      }
      .padding(20)
    }
    .font(.system(size: 15))
    .alert("Delete task?", isPresented: $confirmDeletion) {
      Button("Cancel", role: .cancel) {}
      Button("Delete", role: .destructive, action: requestDelete)
    } message: {
      Text("“\(task.title)” and its subtasks and note will be deleted.")
    }
  }

  private func addStep() {
    if state.addSubtask(to: task.id, title: newStep) {
      newStep = ""
      stepFocused = true
    }
  }
}

// Keep an empty title editable without committing it or snapping the field back mid-keystroke.
private struct EditableTaskTitle: View {
  let title: String
  let completed: Bool
  let font: Font
  let label: String
  let save: (String) -> Void
  @State private var draft: String
  @FocusState private var focused: Bool

  init(title: String, completed: Bool, font: Font, label: String, save: @escaping (String) -> Void)
  {
    self.title = title
    self.completed = completed
    self.font = font
    self.label = label
    self.save = save
    _draft = State(initialValue: title)
  }

  var body: some View {
    TextField(label, text: $draft, axis: .vertical)
      .textFieldStyle(.plain).font(font).strikethrough(completed)
      .foregroundStyle(completed ? .secondary : .primary)
      .focused($focused).accessibilityLabel(label)
      .onChange(of: draft) { _, value in
        if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { save(value) }
      }
      .onChange(of: title) { _, value in if !focused { draft = value } }
      .onChange(of: focused) { _, value in if !value { draft = title } }
  }
}
