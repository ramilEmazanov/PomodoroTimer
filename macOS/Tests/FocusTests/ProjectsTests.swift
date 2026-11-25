import Foundation
import SQLite3
import Testing

@testable import Focus

@MainActor
private final class ProjectClock {
  var now = Date(timeIntervalSince1970: 1_800_000_000)
  func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

@MainActor
private final class ProjectStore: FocusStorage {
  var snapshot = SavedFocusState()
  var records: [FocusSession] = []
  var fails = false
  func load() throws -> (SavedFocusState, [FocusSession]) { (snapshot, records) }
  func save(_ state: SavedFocusState, adding sessions: [FocusSession]) throws {
    if fails { throw CocoaError(.fileWriteOutOfSpace) }
    snapshot = state
    let ids = Set(records.map(\.id))
    records += sessions.filter { !ids.contains($0.id) }
  }
}

@MainActor
struct ProjectsTests {
  @Test func completedTasksAreExcludedFromTimerSelection() throws {
    let state = InterfaceState(store: ProjectStore())
    let active = try #require(state.addTask(title: "Active"))
    let completed = try #require(state.addTask(title: "Completed"))
    state.prepareTimer(for: completed)
    state.editTask(completed) { $0.isCompleted = true }
    #expect(state.timerTaskID == nil)
    #expect(state.timerTasks.map(\.id) == [active])

    state.section = .tasks
    state.prepareTimer(for: completed)
    #expect(state.timerTaskID == nil)
    #expect(state.section == .tasks)

    state.timerTaskID = completed
    state.start(60)
    #expect(state.saved.active?.assignment == nil)
    state.reset()

    state.editTask(completed) { $0.isCompleted = false }
    #expect(state.timerTasks.contains { $0.id == completed })
    state.prepareTimer(for: completed)
    #expect(state.timerTaskID == completed)
  }

  @Test func completingTaskKeepsRunningTimerAssignment() throws {
    let clock = ProjectClock()
    let state = InterfaceState(store: ProjectStore(), clock: { clock.now })
    let task = try #require(state.addTask(title: "Task"))
    state.prepareTimer(for: task)
    state.start(60)
    state.editTask(task) { $0.isCompleted = true }
    #expect(state.timerTasks.isEmpty)
    #expect(state.timerTaskID == nil)
    #expect(state.saved.active?.assignment?.taskID == task)
    clock.advance(60)
    state.refresh()
    #expect(state.sessions.first?.assignment?.taskID == task)
    #expect(state.focusedSeconds(taskID: task) == 60)
  }

  @Test func projectsTasksSubtasksAndActiveAssignmentSurviveRestart() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "focus.sqlite")
    let clock = ProjectClock()
    let projectID: UUID
    let taskID: UUID
    do {
      let state = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { clock.now })
      projectID = try #require(state.addProject(title: " C++ "))
      taskID = try #require(state.addTask(title: "Move semantics", projectID: projectID))
      #expect(state.addSubtask(to: taskID, title: "Read reference"))
      state.prepareTimer(for: taskID)
      state.start(60)
      clock.advance(10)
      state.pauseOrResume()
    }
    let restored = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { clock.now })
    #expect(restored.projects.first?.title == "C++")
    #expect(restored.tasks.first?.projectID == projectID)
    #expect(restored.tasks.first?.subtasks.first?.title == "Read reference")
    #expect(restored.saved.active?.assignment?.taskID == taskID)
    clock.advance(600)
    #expect(restored.focusedSeconds(taskID: taskID) == 10)
    restored.pauseOrResume()
    clock.advance(1000)
    restored.refresh()
    #expect(restored.focusedSeconds(taskID: taskID) == 60)
    #expect(restored.focusedSeconds(projectID: projectID) == 60)
    let again = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { clock.now })
    #expect(again.sessions.count == 1)
    #expect(again.focusedSeconds(projectID: projectID) == 60)
  }

  @Test func movingAndDeletingTaskPreservesOriginalProjectTime() throws {
    let clock = ProjectClock()
    let state = InterfaceState(store: ProjectStore(), clock: { clock.now })
    let original = try #require(state.addProject(title: "Original"))
    let next = try #require(state.addProject(title: "Next"))
    let task = try #require(state.addTask(title: "Task", projectID: original))
    state.prepareTimer(for: task)
    state.start(60)
    clock.advance(12)
    state.editTask(task) {
      $0.projectID = next
      $0.title = "Renamed"
    }
    state.renameProject(original, title: "Renamed project")
    state.refresh()
    #expect(state.focusedSeconds(projectID: original) == 12)
    #expect(state.focusedSeconds(projectID: next) == 0)
    state.reset()
    #expect(state.sessions.first?.assignment?.projectTitle == "Original")
    #expect(state.sessions.first?.assignment?.taskTitle == "Task")
    state.prepareTimer(for: task)
    state.start(30)
    clock.advance(30)
    state.refresh()
    #expect(state.focusedSeconds(taskID: task) == 42)
    #expect(state.focusedSeconds(projectID: original) == 12)
    #expect(state.focusedSeconds(projectID: next) == 30)
    state.deleteTask(task)
    #expect(state.focusedSeconds(projectID: original) == 12)
    #expect(state.focusedSeconds(projectID: next) == 30)
  }

  @Test func failedCompletionDoesNotDoubleCountAndPendingProjectsRetryTogether() throws {
    let clock = ProjectClock()
    let store = ProjectStore()
    let state = InterfaceState(store: store, clock: { clock.now })
    store.fails = true
    let project = try #require(state.addProject(title: "Draft"))
    let task = try #require(state.addTask(title: "Draft task", projectID: project))
    #expect(state.pendingProjects != nil)
    #expect(state.pendingTasks != nil)
    store.fails = false
    state.retryStorage()
    #expect(state.pendingProjects == nil)
    #expect(state.pendingTasks == nil)
    state.prepareTimer(for: task)
    state.start(20)
    store.fails = true
    clock.advance(60)
    state.refresh()
    #expect(state.focusedSeconds(projectID: project) == 20)
    #expect(store.records.isEmpty)
    store.fails = false
    state.retryStorage()
    state.refresh()
    #expect(state.focusedSeconds(projectID: project) == 20)
    #expect(store.records.count == 1)
    store.fails = true
    state.deleteProject(project)
    #expect(state.tasks.first?.projectID == nil)
    #expect(store.snapshot.tasks.first?.projectID == project)
    store.fails = false
    state.retryStorage()
    #expect(store.snapshot.projects.isEmpty)
    #expect(store.snapshot.tasks.first?.projectID == nil)
    #expect(state.focusedSeconds(taskID: task) == 20)
  }

  @Test func versionTwoPayloadsDecodeWithoutProjectsOrAssignments() throws {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let task = FocusTask(id: UUID(), title: "Existing task", createdAt: now, updatedAt: now)
    var original = SavedFocusState()
    original.tasks = [task]
    original.active = ActiveSession(
      id: UUID(), startedAt: now, plannedSeconds: 60, runningSince: now)
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
    object.removeValue(forKey: "projects")
    let data = try JSONSerialization.data(withJSONObject: object)
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "focus.sqlite")
    do { try SQLiteFocusStore(url: url).save(original, adding: []) }
    var db: OpaquePointer?
    #expect(sqlite3_open(url.path, &db) == SQLITE_OK)
    defer { sqlite3_close(db) }
    let hex = data.map { String(format: "%02x", $0) }.joined()
    #expect(
      sqlite3_exec(
        db, "UPDATE app_state SET payload=X'\(hex)'; PRAGMA user_version=2;", nil, nil, nil)
        == SQLITE_OK)
    let restored = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { now })
    #expect(restored.loaded)
    #expect(restored.projects.isEmpty)
    #expect(restored.tasks == [task])
    #expect(restored.saved.active?.assignment == nil)
    restored.reset()
    #expect(restored.addProject(title: "New project") != nil)
    #expect(restored.addTask(title: "Invalid", projectID: UUID()) == nil)
    #expect(restored.addProject(title: "  ") == nil)
    let legacySession = FocusSession(
      id: UUID(), startedAt: now, endedAt: now, plannedSeconds: 1, outcome: .completed,
      intervals: [])
    let decoded = try JSONDecoder().decode(
      FocusSession.self, from: JSONEncoder().encode(legacySession))
    #expect(decoded.assignment == nil)
  }
}
