import SwiftUI

// Presentation-only state. No clock, persistence, network, or session accounting.
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
  enum Preview: String, CaseIterable, Identifiable {
    case homeData = "Home with data"
    case homeEmpty = "Empty home"
    case setup = "Timer setup"
    case error = "Validation error"
    case running = "Running timer"
    case paused = "Pause"
    case dialog = "Reset dialog"
    case finished = "Finished timer"
    var id: Self { self }
  }

  var section: Section = .home
  var dark = false
  var emptyHome = false
  var phase: TimerPhase = .setup
  var entryMode: EntryMode = .wheel
  var fields = ["00", "25", "00"]
  var remaining = 1500
  var total = 1500
  var recents: [Int] = []
  var showReset = false

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
    guard phase != .running, phase != .paused else { return }
    if seconds == nil && validation != nil { return }
    let value = seconds ?? duration
    guard (1...86399).contains(value) else { return }
    setDuration(value)
    remaining = value
    total = value
    recents = Array(([value] + recents.filter { $0 != value }).prefix(8))
    phase = .running
  }

  func reset() {
    showReset = false
    setDuration(total)
    phase = .setup
  }

  func preview(_ preview: Preview) {
    showReset = false
    if preview == .homeData || preview == .homeEmpty {
      emptyHome = preview == .homeEmpty
      section = .home
      return
    }
    section = .timer
    setDuration(preview == .error ? 0 : 1500)
    total = 1500
    remaining = preview == .finished ? 0 : 754
    switch preview {
    case .setup, .error: phase = .setup
    case .paused: phase = .paused
    case .finished: phase = .finished
    default: phase = .running
    }
    showReset = preview == .dialog
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
