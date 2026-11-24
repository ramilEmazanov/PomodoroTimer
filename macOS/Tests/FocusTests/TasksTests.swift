import Foundation
import SQLite3
import Testing

@testable import Focus

@MainActor
private final class TaskTestStore: FocusStorage {
  var state = SavedFocusState()
  var fail = false
  func load() throws -> (SavedFocusState, [FocusSession]) { (state, []) }
  func save(_ state: SavedFocusState, adding sessions: [FocusSession]) throws {
    if fail { throw CocoaError(.fileWriteOutOfSpace) }
    self.state = state
  }
}

@MainActor
struct TasksTests {
  @Test func completionOrderSurvivesEditsRestartAndRecompletion() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "focus.sqlite")
    var instant = Date(timeIntervalSince1970: 1_800_000_000)
    let state = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { instant })
    let first = try #require(state.addTask(title: "A"))
    let second = try #require(state.addTask(title: "Z"))
    state.editTask(first) { $0.isCompleted = true }
    let firstCompletion = instant
    instant += 60
    state.editTask(second) { $0.isCompleted = true }
    instant += 60
    state.editTask(first) { $0.note = "Edited after completion" }
    #expect(state.tasks.first { $0.id == first }?.completedAt == firstCompletion)
    for sort in TaskSort.allCases {
      #expect(sort.sorted(state.tasks).map(\.id) == [second, first])
    }

    let restored = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { instant })
    #expect(TaskSort.dueDate.sorted(restored.tasks).map(\.id) == [second, first])
    #expect(restored.tasks.first { $0.id == first }?.completedAt == firstCompletion)
    restored.editTask(first) { $0.isCompleted = false }
    #expect(restored.tasks.first { $0.id == first }?.completedAt == nil)
    instant += 60
    restored.editTask(first) { $0.isCompleted = true }
    #expect(restored.tasks.first { $0.id == first }?.completedAt == instant)
    #expect(TaskSort.dueDate.sorted(restored.tasks).map(\.id) == [first, second])
  }

  @Test func legacyCompletedTasksUseLastUpdateUntilRecompleted() throws {
    let date = Date(timeIntervalSince1970: 1_800_000_000)
    var legacy = FocusTask(id: UUID(), title: "Legacy", createdAt: date, updatedAt: date)
    legacy.isCompleted = true
    let data = try JSONEncoder().encode(legacy)
    let decoded = try JSONDecoder().decode(FocusTask.self, from: data)
    #expect(decoded.completedAt == nil)
    let store = TaskTestStore()
    store.state.tasks = [decoded]
    let state = InterfaceState(store: store, clock: { date.addingTimeInterval(60) })
    state.editTask(legacy.id) { $0.note = "New note" }
    #expect(state.tasks.first?.completedAt == date)
    let recent = FocusTask(
      id: UUID(), title: "Recent", createdAt: date, updatedAt: date.addingTimeInterval(30),
      isCompleted: true)
    #expect(TaskSort.title.sorted([decoded, recent]).map(\.id) == [recent.id, decoded.id])
  }

  @Test func tasksAndSubtasksSurviveSQLiteRestartAndCanBeEditedAndDeleted() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "focus.sqlite")
    let due = Date(timeIntervalSince1970: 1_900_000_000)
    let taskID: UUID
    let secondID: UUID
    do {
      let state = InterfaceState(store: try SQLiteFocusStore(url: url))
      taskID = try #require(state.addTask(title: "  Подготовить проект  "))
      secondID = try #require(state.addTask(title: "Another task"))
      state.editTask(taskID) {
        $0.note = "Первая строка\nСсылка и заметка 👋"
        $0.dueDate = due
        $0.isImportant = true
      }
      #expect(state.addSubtask(to: taskID, title: "Первый шаг"))
      #expect(state.addSubtask(to: taskID, title: "Второй шаг"))
      let step = try #require(state.tasks.first { $0.id == taskID }?.subtasks.first)
      state.editSubtask(step.id, in: taskID) { $0.isCompleted = true }
    }
    let restored = InterfaceState(store: try SQLiteFocusStore(url: url))
    let task = try #require(restored.tasks.first { $0.id == taskID })
    #expect(task.title == "Подготовить проект")
    #expect(task.note == "Первая строка\nСсылка и заметка 👋")
    #expect(task.dueDate == due)
    #expect(task.isImportant)
    #expect(task.completedSteps == 1)
    #expect(!task.isCompleted)
    let subtask = try #require(task.subtasks.last)
    restored.editSubtask(subtask.id, in: taskID) { $0.title = "Updated step" }
    restored.editTask(taskID) {
      $0.isCompleted = true
      $0.dueDate = nil
      $0.subtasks.removeAll { $0.id == subtask.id }
    }
    restored.deleteTask(secondID)
    let final = InterfaceState(store: try SQLiteFocusStore(url: url))
    #expect(final.tasks.count == 1)
    #expect(final.tasks.first?.isCompleted == true)
    #expect(final.tasks.first?.dueDate == nil)
    #expect(final.tasks.first?.subtasks.count == 1)
    final.deleteTask(taskID)
    let empty = InterfaceState(store: try SQLiteFocusStore(url: url))
    #expect(empty.tasks.isEmpty)
  }

  @Test func versionOneDatabaseKeepsTimerHistoryAndPreferences() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "focus.sqlite")
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    var original = SavedFocusState()
    original.dark = true
    original.recents = [300, 60]
    original.lastDuration = 300
    original.active = ActiveSession(
      id: UUID(), startedAt: now, plannedSeconds: 300, runningSince: now)
    let session = FocusSession(
      id: UUID(), startedAt: now.addingTimeInterval(-60), endedAt: now,
      plannedSeconds: 60, outcome: .completed,
      intervals: [FocusInterval(start: now.addingTimeInterval(-60), end: now)])
    do {
      let store = try SQLiteFocusStore(url: url)
      try store.save(original, adding: [session])
    }
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    object.removeValue(forKey: "tasks")
    let oldPayload = try JSONSerialization.data(withJSONObject: object)
    let hex = oldPayload.map { String(format: "%02x", $0) }.joined()
    var db: OpaquePointer?
    #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    #expect(
      sqlite3_exec(
        db, "UPDATE app_state SET payload=X'\(hex)'; PRAGMA user_version=1;", nil, nil, nil)
        == SQLITE_OK)
    let state = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { now })
    #expect(state.loaded)
    #expect(state.tasks.isEmpty)
    #expect(state.saved.active == original.active)
    #expect(state.sessions == [session])
    #expect(state.dark)
    #expect(state.recents == original.recents)
    #expect(state.addTask(title: "New task") != nil)
    let final = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { now })
    #expect(final.tasks.count == 1)
    #expect(final.saved.active == original.active)
    #expect(final.sessions == [session])
  }

  @Test func failedTaskWritesRetainDraftsUntilRetry() throws {
    let store = TaskTestStore()
    let state = InterfaceState(store: store)
    let id = try #require(state.addTask(title: "Task"))
    store.fail = true
    state.editTask(id) { $0.note = "Unsaved note" }
    #expect(state.tasks.first?.note == "Unsaved note")
    #expect(store.state.tasks.first?.note == "")
    #expect(state.pendingTasks != nil)
    #expect(state.storageError != nil)
    #expect(state.addSubtask(to: id, title: "Unsaved step"))
    store.fail = false
    state.retryStorage()
    #expect(state.pendingTasks == nil)
    #expect(state.storageError == nil)
    let restored = InterfaceState(store: store)
    #expect(restored.tasks.first?.note == "Unsaved note")
    #expect(restored.tasks.first?.subtasks.first?.title == "Unsaved step")
  }

  @Test func timerWritesDoNotDiscardPendingTaskEdits() throws {
    let store = TaskTestStore()
    let state = InterfaceState(store: store)
    store.fail = true
    let id = try #require(state.addTask(title: "Keep this task"))
    state.editTask(id) { $0.isImportant = true }
    store.fail = false
    state.start(60)
    #expect(state.phase == .running)
    #expect(state.pendingTasks == nil)
    #expect(store.state.tasks.first?.id == id)
    #expect(store.state.tasks.first?.isImportant == true)
    #expect(store.state.active != nil)
  }

  @Test func blankTitlesAreRejectedAndTaskCompletionKeepsSubtaskProgress() throws {
    let state = InterfaceState(store: TaskTestStore())
    #expect(state.addTask(title: " \n ") == nil)
    let id = try #require(state.addTask(title: "Task"))
    #expect(!state.addSubtask(to: id, title: "  "))
    state.editTask(id) { $0.title = "" }
    #expect(state.tasks.first?.title == "Task")
    #expect(state.addSubtask(to: id, title: "Step"))
    let stepID = try #require(state.tasks.first?.subtasks.first?.id)
    state.editSubtask(stepID, in: id) { $0.isCompleted = true }
    state.editTask(id) { $0.isCompleted = true }
    state.editTask(id) { $0.isCompleted = false }
    #expect(state.tasks.first?.completedSteps == 1)
  }

  @Test func deadlineSortingAndOverdueRespectDayBoundaries() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let today = Calendar.current.startOfDay(for: now)
    var overdue = FocusTask(id: UUID(), title: "Overdue", createdAt: now, updatedAt: now)
    overdue.dueDate = today.addingTimeInterval(-1)
    var dueToday = FocusTask(id: UUID(), title: "Today", createdAt: now, updatedAt: now)
    dueToday.dueDate = today
    let undated = FocusTask(id: UUID(), title: "Undated", createdAt: now, updatedAt: now)
    #expect(overdue.isOverdue(at: now))
    #expect(!dueToday.isOverdue(at: now))
    #expect(
      TaskSort.dueDate.sorted([undated, dueToday, overdue]).map(\.id) == [
        overdue.id, dueToday.id, undated.id,
      ])
    overdue.isCompleted = true
    #expect(!overdue.isOverdue(at: now))
    #expect(TaskSort.dueDate.sorted([overdue, dueToday]).last?.id == overdue.id)
  }
}
