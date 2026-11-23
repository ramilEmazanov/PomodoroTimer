import Foundation
import SQLite3
import Testing

@testable import Focus

@MainActor
private final class TestClock {
  var now = Date(timeIntervalSince1970: 1_800_000_000)
  func advance(_ seconds: TimeInterval) { now = now.addingTimeInterval(seconds) }
}

@MainActor
private final class MemoryStore: FocusStorage {
  var snapshot = SavedFocusState()
  var records: [FocusSession] = []
  var fails = false
  func load() throws -> (SavedFocusState, [FocusSession]) {
    if fails { throw CocoaError(.fileReadCorruptFile) }
    return (snapshot, records)
  }
  func save(_ state: SavedFocusState, adding sessions: [FocusSession]) throws {
    if fails { throw CocoaError(.fileWriteOutOfSpace) }
    snapshot = state
    let ids = Set(records.map(\.id))
    records += sessions.filter { !ids.contains($0.id) }
  }
}

@MainActor
struct FocusTests {
  @Test func pauseResumeExcludesPausedTimeAndPreventsDuplicateStarts() throws {
    let clock = TestClock()
    let store = MemoryStore()
    let state = InterfaceState(store: store, clock: { clock.now })
    state.start(60)
    let id = state.saved.active?.id
    state.start(300)
    #expect(state.saved.active?.id == id)
    clock.advance(12.5)
    state.pauseOrResume()
    #expect(state.phase == .paused)
    clock.advance(3600)
    state.refresh()
    #expect(state.remaining == 48)
    #expect(state.saved.active?.accumulated == 12.5)
    state.pauseOrResume()
    clock.advance(47.5)
    state.refresh()
    #expect(state.phase == .finished)
    let session = try #require(state.sessions.first)
    #expect(session.focusedSeconds == 60)
    #expect(session.outcome == .completed)
    #expect(session.intervals.count == 2)
    state.refresh()
    #expect(store.records.count == 1)
  }

  @Test func restartAndSleepCompleteAtDeadlineExactlyOnce() throws {
    let clock = TestClock()
    let store = MemoryStore()
    let first = InterfaceState(store: store, clock: { clock.now })
    first.start(30)
    let deadline = try #require(first.saved.active?.deadline)
    clock.advance(7200)
    let restored = InterfaceState(store: store, clock: { clock.now })
    #expect(restored.phase == .finished)
    #expect(restored.sessions.count == 1)
    #expect(restored.sessions.first?.endedAt == deadline)
    #expect(restored.sessions.first?.focusedSeconds == 30)
    let again = InterfaceState(store: store, clock: { clock.now })
    #expect(again.sessions.count == 1)
    #expect(again.saved.active == nil)
  }

  @Test func pausedTimerSurvivesRestartAndCancellationKeepsPartialFocus() throws {
    let clock = TestClock()
    let store = MemoryStore()
    let first = InterfaceState(store: store, clock: { clock.now })
    first.start(60)
    clock.advance(20)
    first.pauseOrResume()
    clock.advance(600)
    let restored = InterfaceState(store: store, clock: { clock.now })
    #expect(restored.phase == .paused)
    #expect(restored.remaining == 40)
    restored.reset()
    let session = try #require(restored.sessions.first)
    #expect(session.outcome == .cancelled)
    #expect(session.focusedSeconds == 20)
    let range = DateInterval(start: session.startedAt, duration: 86400)
    #expect(restored.history.completed(in: range) == 0)
    #expect(restored.history.focusedSeconds(in: range) == 20)
  }

  @Test func focusIsSplitAtMidnightIncludingUnfinishedSession() throws {
    let clock = TestClock()
    let calendar = Calendar(identifier: .gregorian)
    let day = try #require(calendar.dateInterval(of: .day, for: clock.now))
    clock.now = day.end.addingTimeInterval(-30)
    let state = InterfaceState(store: MemoryStore(), clock: { clock.now })
    state.start(120)
    clock.advance(60)
    state.refresh()
    #expect(state.history.focusedSeconds(in: day) == 30)
    let next = DateInterval(start: day.end, duration: 86400)
    #expect(state.history.focusedSeconds(in: next) == 30)
    state.pauseOrResume()
    clock.advance(3600)
    state.refresh()
    #expect(state.history.focusedSeconds(in: next) == 30)
    state.reset()
    #expect(state.history.focusedSeconds(in: day) == 30)
    #expect(state.history.focusedSeconds(in: next) == 30)
  }

  @Test func storageFailureDoesNotPretendToStartOrDiscardActiveSession() {
    let clock = TestClock()
    let store = MemoryStore()
    let state = InterfaceState(store: store, clock: { clock.now })
    store.fails = true
    state.start(60)
    #expect(state.saved.active == nil)
    #expect(state.storageError != nil)
    store.fails = false
    state.start(60)
    clock.advance(60)
    store.fails = true
    state.refresh()
    #expect(state.saved.active != nil)
    #expect(state.sessions.isEmpty)
    store.fails = false
    state.retryStorage()
    #expect(state.sessions.count == 1)
    #expect(state.saved.active == nil)
    #expect(state.storageError == nil)
  }

  @Test func unreadableStorageDoesNotGetOverwritten() {
    let store = MemoryStore()
    store.fails = true
    let state = InterfaceState(store: store)
    #expect(!state.loaded)
    state.start(60)
    state.dark = true
    #expect(store.snapshot == SavedFocusState())
    store.fails = false
    state.retryStorage()
    #expect(state.loaded)
    #expect(state.storageError == nil)
  }

  @Test(arguments: ["", "-1", "1.5", "60", "9223372036854775807", "abc"])
  func invalidInputCannotStartOrOverflow(_ input: String) {
    let state = InterfaceState(store: MemoryStore())
    state.fields = ["00", input, "00"]
    #expect(state.validation != nil)
    state.start()
    #expect(state.saved.active == nil)
  }

  @Test func sqliteRoundTripRestoresHistoryRecentsThemeAndActiveTimer() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "focus.sqlite")
    let clock = TestClock()
    do {
      let store = try SQLiteFocusStore(url: url)
      let state = InterfaceState(store: store, clock: { clock.now })
      state.dark = true
      state.start(5)
      clock.advance(5)
      state.refresh()
      state.start(90)
      clock.advance(12)
      state.pauseOrResume()
    }
    let reopened = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { clock.now })
    #expect(reopened.loaded)
    #expect(reopened.dark)
    #expect(reopened.sessions.count == 1)
    #expect(reopened.sessions.first?.focusedSeconds == 5)
    #expect(reopened.recents == [90, 5])
    #expect(reopened.phase == .paused)
    #expect(reopened.remaining == 78)
    reopened.reset()
    let final = InterfaceState(store: try SQLiteFocusStore(url: url), clock: { clock.now })
    #expect(final.sessions.count == 2)
    #expect(final.sessions.first?.focusedSeconds == 12)
    #expect(final.saved.active == nil)
  }

  @Test func sqliteSaveIsIdempotentForTheSameSession() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try SQLiteFocusStore(url: directory.appending(path: "focus.sqlite"))
    let clock = TestClock()
    let state = InterfaceState(store: store, clock: { clock.now })
    state.start(5)
    clock.advance(5)
    state.refresh()
    let session = try #require(state.sessions.first)
    try store.save(state.saved, adding: [session, session])
    let (_, sessions) = try store.load()
    #expect(sessions.count == 1)
  }

  @Test func sqliteCorruptionIsReportedWithoutReplacingFile() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "focus.sqlite")
    let original = Data("unreadable database".utf8)
    try original.write(to: url)
    #expect(throws: (any Error).self) { _ = try SQLiteFocusStore(url: url) }
    #expect(try Data(contentsOf: url) == original)
  }

  @Test func sqliteRollsBackActiveStateWhenHistoryWriteFails() throws {
    let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appending(path: "focus.sqlite")
    let store = try SQLiteFocusStore(url: url)
    let clock = TestClock()
    let state = InterfaceState(store: store, clock: { clock.now })
    state.start(5)
    var database: OpaquePointer?
    #expect(sqlite3_open(url.path, &database) == SQLITE_OK)
    defer { sqlite3_close(database) }
    #expect(
      sqlite3_exec(
        database,
        "CREATE TRIGGER reject_session BEFORE INSERT ON sessions BEGIN SELECT RAISE(ABORT, 'test failure'); END",
        nil, nil, nil) == SQLITE_OK)
    clock.advance(5)
    state.refresh()
    #expect(state.storageError != nil)
    let (snapshot, records) = try store.load()
    #expect(snapshot.active != nil)
    #expect(records.isEmpty)
    #expect(sqlite3_exec(database, "DROP TRIGGER reject_session", nil, nil, nil) == SQLITE_OK)
    state.retryStorage()
    let (finished, sessions) = try store.load()
    #expect(finished.active == nil)
    #expect(sessions.count == 1)
  }

  @Test func daylightSavingDayUsesActualElapsedTime() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/New_York"))
    let date = try #require(
      calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 12)))
    let range = try #require(calendar.dateInterval(of: .day, for: date))
    #expect(range.duration == 23 * 3600)
    let session = FocusSession(
      id: UUID(), startedAt: range.start, endedAt: range.end,
      plannedSeconds: 86399, outcome: .cancelled,
      intervals: [FocusInterval(start: range.start, end: range.end)])
    let history = FocusHistory(sessions: [session], active: nil, now: range.end)
    #expect(history.focusedSeconds(in: range) == 23 * 3600)
  }
}
