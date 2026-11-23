import Foundation

struct FocusInterval: Codable, Equatable {
  let start: Date
  let end: Date

  func duration(in range: DateInterval) -> TimeInterval {
    max(0, min(end, range.end).timeIntervalSince(max(start, range.start)))
  }
}

struct FocusSession: Codable, Identifiable, Equatable {
  enum Outcome: String, Codable { case completed, cancelled }
  let id: UUID
  let startedAt: Date
  let endedAt: Date
  let plannedSeconds: Int
  let outcome: Outcome
  let intervals: [FocusInterval]

  var focusedSeconds: TimeInterval {
    intervals.reduce(0) { $0 + max(0, $1.end.timeIntervalSince($1.start)) }
  }
}

struct ActiveSession: Codable, Equatable {
  let id: UUID
  let startedAt: Date
  let plannedSeconds: Int
  var intervals: [FocusInterval] = []
  var runningSince: Date?

  var accumulated: TimeInterval {
    intervals.reduce(0) { $0 + max(0, $1.end.timeIntervalSince($1.start)) }
  }

  var deadline: Date? {
    runningSince?.addingTimeInterval(max(0, Double(plannedSeconds) - accumulated))
  }

  func remaining(at now: Date) -> TimeInterval {
    if let deadline { return min(Double(plannedSeconds), max(0, deadline.timeIntervalSince(now))) }
    return max(0, Double(plannedSeconds) - accumulated)
  }

  mutating func stop(at now: Date) {
    if let start = runningSince, let deadline {
      let end = max(start, min(now, deadline))
      if end > start { intervals.append(FocusInterval(start: start, end: end)) }
    }
    runningSince = nil
  }

  func record(outcome: FocusSession.Outcome, at now: Date) -> FocusSession {
    var copy = self
    let end = outcome == .completed ? (deadline ?? now) : now
    copy.stop(at: end)
    return FocusSession(
      id: id, startedAt: startedAt, endedAt: end,
      plannedSeconds: plannedSeconds, outcome: outcome, intervals: copy.intervals)
  }
}

struct SavedFocusState: Codable, Equatable {
  var active: ActiveSession?
  var recents: [Int] = []
  var dark: Bool?
  var lastDuration = 1500
  var tasks: [FocusTask] = []

  init() {}

  private enum CodingKeys: String, CodingKey {
    case active, recents, dark, lastDuration, tasks
  }

  // Version 1 snapshots predate Tasks. Keep their timer, history and preferences intact.
  init(from decoder: any Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    active = try values.decodeIfPresent(ActiveSession.self, forKey: .active)
    recents = try values.decode([Int].self, forKey: .recents)
    dark = try values.decodeIfPresent(Bool.self, forKey: .dark)
    lastDuration = try values.decode(Int.self, forKey: .lastDuration)
    tasks = try values.decodeIfPresent([FocusTask].self, forKey: .tasks) ?? []
  }
}

struct FocusHistory {
  let sessions: [FocusSession]
  let active: ActiveSession?
  let now: Date

  // Split actual focus intervals at calendar boundaries, including sessions spanning midnight.
  func focusedSeconds(in range: DateInterval) -> TimeInterval {
    let recorded = sessions.flatMap(\.intervals)
    var current = active?.intervals ?? []
    if let active, let start = active.runningSince, let deadline = active.deadline {
      current.append(FocusInterval(start: start, end: max(start, min(now, deadline))))
    }
    return (recorded + current).reduce(0) { $0 + $1.duration(in: range) }
  }

  func completed(in range: DateInterval) -> Int {
    sessions.filter {
      $0.outcome == .completed && $0.endedAt >= range.start && $0.endedAt < range.end
    }.count
  }

  static func display(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(seconds.rounded(.down)))
    if value < 60 { return "\(value) sec" }
    if value < 3600 { return "\(value / 60) min" }
    return "\(value / 3600) h \(value / 60 % 60) min"
  }
}
