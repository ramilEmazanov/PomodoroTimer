import Foundation
import SQLite3

protocol FocusStorage {
  func load() throws -> (SavedFocusState, [FocusSession])
  func save(_ state: SavedFocusState, adding sessions: [FocusSession]) throws
}

enum FocusStoreError: LocalizedError {
  case database(String)
  case incompatibleVersion
  var errorDescription: String? {
    switch self {
    case .database(let message): "Local storage: \(message)"
    case .incompatibleVersion:
      "This database was created by a newer version of Focus. Update the app to open it."
    }
  }
}

final class SQLiteFocusStore: FocusStorage {
  static var defaultURL: URL {
    URL.applicationSupportDirectory.appending(
      path: Bundle.main.bundleIdentifier ?? "local.pomodoro.Focus", directoryHint: .isDirectory
    )
    .appending(path: "focus.sqlite")
  }

  private var database: OpaquePointer?
  private let encoder = JSONEncoder()
  private let decoder = JSONDecoder()

  init(url: URL = SQLiteFocusStore.defaultURL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard
      sqlite3_open_v2(
        url.path, &database, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil
      ) == SQLITE_OK
    else {
      let error = failure()
      sqlite3_close(database)
      database = nil
      throw error
    }
    do {
      sqlite3_busy_timeout(database, 3000)
      try execute("PRAGMA journal_mode=WAL")
      try execute("PRAGMA synchronous=FULL")
      let version = try statement("PRAGMA user_version")
      defer { sqlite3_finalize(version) }
      guard sqlite3_step(version) == SQLITE_ROW else { throw failure() }
      guard sqlite3_column_int(version, 0) <= 3 else { throw FocusStoreError.incompatibleVersion }
      try execute(
        """
        CREATE TABLE IF NOT EXISTS app_state (id INTEGER PRIMARY KEY CHECK(id = 1), payload BLOB NOT NULL);
        CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY NOT NULL, payload BLOB NOT NULL);
        PRAGMA user_version=3;
        """)
    } catch {
      sqlite3_close(database)
      database = nil
      throw error
    }
  }

  isolated deinit { sqlite3_close(database) }

  func load() throws -> (SavedFocusState, [FocusSession]) {
    let stateQuery = try statement("SELECT payload FROM app_state WHERE id=1")
    defer { sqlite3_finalize(stateQuery) }
    let result = sqlite3_step(stateQuery)
    let state: SavedFocusState
    if result == SQLITE_ROW {
      state = try decoder.decode(SavedFocusState.self, from: payload(stateQuery))
    } else if result == SQLITE_DONE {
      state = SavedFocusState()
    } else {
      throw failure()
    }

    let sessionQuery = try statement("SELECT payload FROM sessions")
    defer { sqlite3_finalize(sessionQuery) }
    var sessions: [FocusSession] = []
    while true {
      let result = sqlite3_step(sessionQuery)
      if result == SQLITE_DONE { break }
      guard result == SQLITE_ROW else { throw failure() }
      sessions.append(try decoder.decode(FocusSession.self, from: payload(sessionQuery)))
    }
    return (state, sessions.sorted { $0.endedAt > $1.endedAt })
  }

  // The completed session and clearing its active state commit together, preventing double counting.
  func save(_ state: SavedFocusState, adding sessions: [FocusSession]) throws {
    try execute("BEGIN IMMEDIATE")
    do {
      let query = try statement(
        "INSERT INTO app_state(id, payload) VALUES(1, ?) ON CONFLICT(id) DO UPDATE SET payload=excluded.payload"
      )
      defer { sqlite3_finalize(query) }
      try bind(try encoder.encode(state), to: query, at: 1)
      guard sqlite3_step(query) == SQLITE_DONE else { throw failure() }
      for session in sessions {
        let query = try statement("INSERT OR IGNORE INTO sessions(id, payload) VALUES(?, ?)")
        defer { sqlite3_finalize(query) }
        try bind(Data(session.id.uuidString.utf8), to: query, at: 1, text: true)
        try bind(try encoder.encode(session), to: query, at: 2)
        guard sqlite3_step(query) == SQLITE_DONE else { throw failure() }
      }
      try execute("COMMIT")
    } catch {
      try? execute("ROLLBACK")
      throw error
    }
  }

  private func execute(_ sql: String) throws {
    guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else { throw failure() }
  }

  private func statement(_ sql: String) throws -> OpaquePointer {
    var query: OpaquePointer?
    guard sqlite3_prepare_v2(database, sql, -1, &query, nil) == SQLITE_OK, let query else {
      throw failure()
    }
    return query
  }

  private func bind(_ data: Data, to query: OpaquePointer, at index: Int32, text: Bool = false)
    throws
  {
    let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    let result = data.withUnsafeBytes { bytes in
      if text {
        return sqlite3_bind_text(
          query, index, bytes.baseAddress?.assumingMemoryBound(to: CChar.self), Int32(data.count),
          transient)
      }
      return sqlite3_bind_blob(query, index, bytes.baseAddress, Int32(data.count), transient)
    }
    guard result == SQLITE_OK else { throw failure() }
  }

  private func payload(_ query: OpaquePointer) -> Data {
    guard let bytes = sqlite3_column_blob(query, 0) else { return Data() }
    return Data(bytes: bytes, count: Int(sqlite3_column_bytes(query, 0)))
  }

  private func failure() -> FocusStoreError {
    .database(
      database.map { String(cString: sqlite3_errmsg($0)) } ?? "Could not open the database.")
  }
}
