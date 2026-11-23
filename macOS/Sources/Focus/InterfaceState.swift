import SwiftUI

@Observable
final class InterfaceState {
  enum Section: String, CaseIterable, Identifiable {
    case home = "Home"
    case timer = "Timer"
    case statistics = "Statistics"
    case settings = "Settings"
    var id: Self { self }
    var symbol: String {
      switch self {
      case .home: "house"
      case .timer: "timer"
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
  var storageError: String?
  private(set) var phase: TimerPhase = .setup
  private(set) var saved = SavedFocusState()
  private(set) var sessions: [FocusSession] = []
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
    candidate.active = ActiveSession(
      id: UUID(), startedAt: instant, plannedSeconds: value, runningSince: instant)
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
    now = clock()
    guard storageError == nil || retry else { return }
    guard let active = saved.active, let deadline = active.deadline, now >= deadline else { return }
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
      try store.save(candidate, adding: records)
      saved = candidate
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
