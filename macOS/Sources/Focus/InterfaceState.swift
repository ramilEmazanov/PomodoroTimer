import SwiftUI

@Observable
final class InterfaceState {
  enum Section: String, CaseIterable, Identifiable {
    case home = "Home"
    case timer = "Timer"
    case tasks = "Tasks"
    case projects = "Projects"
    case statistics = "Statistics"
    case settings = "Settings"
    var id: Self { self }
    var symbol: String {
      switch self {
      case .home: "house"
      case .timer: "timer"
      case .tasks: "checklist"
      case .projects: "folder"
      case .statistics: "chart.bar"
      case .settings: "gearshape"
      }
    }
  }

  enum TimerPhase { case setup, running, paused, finished }
  enum EntryMode: String, CaseIterable {
    case wheel = "Wheel"
    case input = "Input"
  }

  var section: Section = .home
  var entryMode: EntryMode = .wheel
  var fields = ["00", "25", "00"]
  var showReset = false
  var timerTaskID: UUID?
  var storageError: String?
  private(set) var phase: TimerPhase = .setup
  private(set) var saved = SavedFocusState()
  private(set) var sessions: [FocusSession] = []
  private(set) var pendingTasks: [FocusTask]?
  private(set) var pendingProjects: [FocusProject]?
  private(set) var now: Date
  private(set) var loaded = false
  @ObservationIgnored private var store: (any FocusStorage)?
  @ObservationIgnored private let clock: () -> Date

  init(store: (any FocusStorage)? = nil, clock: @escaping () -> Date = { .now }) {
    self.clock = clock
    now = clock()
    do {
      self.store = try store ?? SQLiteFocusStore()
      try reload()
    } catch { storageError = error.localizedDescription }
  }

  var dark: Bool {
    get { saved.dark ?? false }
    set {
      var candidate = saved
      candidate.dark = newValue
      _ = commit(candidate)
    }
  }
  var recents: [Int] { saved.recents }
  var total: Int { saved.active?.plannedSeconds ?? saved.lastDuration }
  var remaining: Int {
    if phase == .finished { return 0 }
    return Int(ceil(saved.active?.remaining(at: now) ?? Double(saved.lastDuration)))
  }
  var history: FocusHistory { FocusHistory(sessions: sessions, active: saved.active, now: now) }

  var duration: Int {
    fields.enumerated().reduce(0) { total, field in
      let maximum = field.offset == 0 ? 23 : 59
      guard let value = Int(field.element), (0...maximum).contains(value) else { return total }
      return total + value * [3600, 60, 1][field.offset]
    }
  }

  var validation: String? {
    for (index, field) in fields.enumerated() {
      let label = ["Hours", "Minutes", "Seconds"][index]
      let maximum = index == 0 ? 23 : 59
      if field.isEmpty { return "Enter a value for \(label)." }
      guard field.allSatisfy({ $0.isASCII && $0.isNumber }),
        let value = Int(field), (0...maximum).contains(value)
      else { return "\(label) must be a whole number from 0 to \(maximum)." }
    }
    return duration > 0 ? nil : "Choose a duration of at least 1 second."
  }

  func setDuration(_ seconds: Int) {
    fields = [seconds / 3600, seconds / 60 % 60, seconds % 60].map { String(format: "%02d", $0) }
  }

  func start(_ seconds: Int? = nil) {
    guard loaded, saved.active == nil else { return }
    if seconds == nil && validation != nil { return }
    let value = seconds ?? duration
    guard (1...86399).contains(value) else { return }
    let instant = clock()
    var candidate = saved
    let task = timerTasks.first { $0.id == timerTaskID }
    let assignment = task.map { task in
      FocusAssignment(
        taskID: task.id, taskTitle: task.title, projectID: task.projectID,
        projectTitle: projects.first { $0.id == task.projectID }?.title)
    }
    candidate.active = ActiveSession(
      id: UUID(), startedAt: instant, plannedSeconds: value, runningSince: instant,
      assignment: assignment)
    candidate.lastDuration = value
    candidate.recents = Array(([value] + candidate.recents.filter { $0 != value }).prefix(8))
    if commit(candidate) {
      now = instant
      setDuration(value)
      phase = .running
    }
  }

  func pauseOrResume() {
    refresh(retry: true)
    guard storageError == nil, var active = saved.active else { return }
    let instant = clock()
    if active.runningSince != nil {
      active.stop(at: instant)
    } else {
      active.runningSince = instant
    }
    var candidate = saved
    candidate.active = active
    if commit(candidate) {
      now = instant
      phase = active.runningSince == nil ? .paused : .running
    }
  }

  func reset() {
    refresh(retry: true)
    guard loaded, storageError == nil else { return }
    var candidate = saved
    var records: [FocusSession] = []
    if let active = candidate.active {
      let record = active.record(outcome: .cancelled, at: clock())
      if record.focusedSeconds > 0 { records.append(record) }
    }
    candidate.active = nil
    if commit(candidate, adding: records) {
      showReset = false
      setDuration(saved.lastDuration)
      phase = .setup
    }
  }

  func refresh(retry: Bool = false) {
    let instant = clock()
    let dayChanged = !Calendar.current.isDate(now, inSameDayAs: instant)
    if let active = saved.active, active.runningSince != nil {
      if dayChanged || ceil(active.remaining(at: now)) != ceil(active.remaining(at: instant)) {
        now = instant
      }
    } else if dayChanged {
      now = instant
    }
    guard storageError == nil || retry else { return }
    guard let active = saved.active, let deadline = active.deadline, instant >= deadline else {
      return
    }
    var candidate = saved
    candidate.active = nil
    if commit(candidate, adding: [active.record(outcome: .completed, at: deadline)]) {
      phase = .finished
      showReset = false
    }
  }

  func reload() throws {
    if store == nil { store = try SQLiteFocusStore() }
    guard let store else { return }
    let (snapshot, records) = try store.load()
    saved = snapshot
    sessions = records
    loaded = true
    storageError = nil
    setDuration(saved.lastDuration)
    phase = saved.active.map { $0.runningSince == nil ? .paused : .running } ?? .setup
    refresh()
  }

  func retryStorage() {
    if loaded {
      if commit(saved) { refresh() }
    } else {
      do { try reload() } catch { storageError = error.localizedDescription }
    }
  }

  private func commit(_ candidate: SavedFocusState, adding records: [FocusSession] = []) -> Bool {
    guard loaded, let store else { return false }
    do {
      var candidate = candidate
      candidate.tasks = pendingTasks ?? candidate.tasks
      candidate.projects = pendingProjects ?? candidate.projects
      try store.save(candidate, adding: records)
      saved = candidate
      pendingTasks = nil
      pendingProjects = nil
      let existing = Set(sessions.map(\.id))
      sessions = (records.filter { !existing.contains($0.id) } + sessions).sorted {
        $0.endedAt > $1.endedAt
      }
      storageError = nil
      return true
    } catch {
      storageError = "Your change could not be saved. \(error.localizedDescription)"
      return false
    }
  }

  var tasks: [FocusTask] { pendingTasks ?? saved.tasks }
  var timerTasks: [FocusTask] { tasks.filter { !$0.isCompleted } }
  var myDayTasks: [FocusTask] { TaskSort.dueDate.sorted(tasks.filter(\.isInMyDay)) }

  func completedTaskCount(in range: DateInterval? = nil) -> Int {
    tasks.filter { task in
      guard task.isCompleted else { return false }
      guard let range else { return true }
      let completion = task.completedAt ?? task.updatedAt
      return completion >= range.start && completion < range.end
    }.count
  }

  func setMyDay(_ taskID: UUID, included: Bool) {
    guard let task = tasks.first(where: { $0.id == taskID }), task.isInMyDay != included else {
      return
    }
    let addedAt = included ? clock() : nil
    editTask(taskID) { $0.myDayAddedAt = addedAt }
  }

  @discardableResult
  func addTask(title: String, projectID: UUID? = nil) -> UUID? {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard loaded, !title.isEmpty,
      projectID == nil || projects.contains(where: { $0.id == projectID })
    else { return nil }
    let instant = clock()
    let task = FocusTask(
      id: UUID(), title: title, createdAt: instant, updatedAt: instant, projectID: projectID)
    saveTasks([task] + tasks)
    return task.id
  }

  func editTask(_ id: UUID, change: (inout FocusTask) -> Void) {
    guard loaded, let index = tasks.firstIndex(where: { $0.id == id }) else { return }
    var updated = tasks
    change(&updated[index])
    let title = updated[index].title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else { return }
    guard
      updated[index].projectID == nil
        || projects.contains(where: { $0.id == updated[index].projectID })
    else { return }
    updated[index].title = title
    guard updated[index] != tasks[index] else { return }
    let instant = clock()
    if updated[index].isCompleted {
      updated[index].completedAt =
        tasks[index].isCompleted
        ? tasks[index].completedAt ?? tasks[index].updatedAt : instant
    } else {
      updated[index].completedAt = nil
    }
    updated[index].updatedAt = instant
    saveTasks(updated)
  }

  func deleteTask(_ id: UUID) {
    guard loaded, tasks.contains(where: { $0.id == id }) else { return }
    saveTasks(tasks.filter { $0.id != id })
    if timerTaskID == id { timerTaskID = nil }
  }

  @discardableResult
  func addSubtask(to id: UUID, title: String) -> Bool {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard loaded, !title.isEmpty, tasks.contains(where: { $0.id == id }) else { return false }
    editTask(id) { $0.subtasks.append(FocusSubtask(id: UUID(), title: title)) }
    return true
  }

  func editSubtask(_ subtaskID: UUID, in taskID: UUID, change: (inout FocusSubtask) -> Void) {
    editTask(taskID) { task in
      guard let index = task.subtasks.firstIndex(where: { $0.id == subtaskID }) else { return }
      var subtask = task.subtasks[index]
      change(&subtask)
      subtask.title = subtask.title.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !subtask.title.isEmpty else { return }
      task.subtasks[index] = subtask
    }
  }

  private func saveTasks(_ tasks: [FocusTask]) {
    // Retain unsaved edits on screen if disk writes fail; Retry storage commits them later.
    pendingTasks = tasks
    if let timerTaskID, !tasks.contains(where: { $0.id == timerTaskID && !$0.isCompleted }) {
      self.timerTaskID = nil
    }
    _ = commit(saved)
  }

  var projects: [FocusProject] { pendingProjects ?? saved.projects }

  @discardableResult
  func addProject(title: String) -> UUID? {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard loaded, !title.isEmpty else { return nil }
    let project = FocusProject(id: UUID(), title: title, createdAt: clock())
    pendingProjects = [project] + projects
    _ = commit(saved)
    return project.id
  }

  func renameProject(_ id: UUID, title: String) {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard loaded, !title.isEmpty, let index = projects.firstIndex(where: { $0.id == id }) else {
      return
    }
    var updated = projects
    updated[index].title = title
    pendingProjects = updated
    _ = commit(saved)
  }

  func deleteProject(_ id: UUID) {
    guard loaded, projects.contains(where: { $0.id == id }) else { return }
    pendingProjects = projects.filter { $0.id != id }
    pendingTasks = tasks.map { task in
      var task = task
      if task.projectID == id { task.projectID = nil }
      return task
    }
    _ = commit(saved)
  }

  func prepareTimer(for taskID: UUID) {
    guard saved.active == nil, timerTasks.contains(where: { $0.id == taskID }) else { return }
    timerTaskID = taskID
    if phase == .finished { phase = .setup }
    section = .timer
  }

  func focusedSeconds(taskID: UUID? = nil, projectID: UUID? = nil) -> TimeInterval {
    func matches(_ assignment: FocusAssignment?) -> Bool {
      guard let assignment else { return false }
      if let taskID { return assignment.taskID == taskID }
      if let projectID { return assignment.projectID == projectID }
      return false
    }
    let recorded = sessions.filter { matches($0.assignment) }.reduce(0) { $0 + $1.focusedSeconds }
    guard let active = saved.active, matches(active.assignment) else { return recorded }
    return recorded + Double(active.plannedSeconds) - active.remaining(at: now)
  }

  static func time(_ seconds: Int) -> String {
    if seconds >= 3600 {
      return String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
    }
    return String(format: "%d:%02d", seconds / 60, seconds % 60)
  }

  static func durationLabel(_ seconds: Int) -> String {
    if seconds == 0 { return "0 sec" }
    return zip([seconds / 3600, seconds / 60 % 60, seconds % 60], ["h", "min", "sec"])
      .compactMap { $0.0 > 0 ? "\($0.0) \($0.1)" : nil }.joined(separator: " ")
  }
}
