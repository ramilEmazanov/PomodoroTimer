import Foundation

struct FocusSubtask: Codable, Identifiable, Equatable {
  let id: UUID
  var title: String
  var isCompleted = false
}

struct FocusTask: Codable, Identifiable, Equatable {
  let id: UUID
  var title: String
  let createdAt: Date
  var updatedAt: Date
  var isCompleted = false
  var isImportant = false
  var dueDate: Date?
  var note = ""
  var subtasks: [FocusSubtask] = []
  var projectID: UUID?

  var completedSteps: Int { subtasks.filter(\.isCompleted).count }

  func isOverdue(at date: Date, calendar: Calendar = .current) -> Bool {
    guard !isCompleted, let dueDate else { return false }
    return calendar.startOfDay(for: dueDate) < calendar.startOfDay(for: date)
  }
}

enum TaskSort: String, CaseIterable, Identifiable {
  case dueDate = "Due date"
  case created = "Newest first"
  case title = "Title"
  case important = "Importance"
  var id: Self { self }

  func sorted(_ tasks: [FocusTask]) -> [FocusTask] {
    tasks.sorted { left, right in
      if left.isCompleted != right.isCompleted { return !left.isCompleted }
      switch self {
      case .dueDate:
        if left.dueDate != right.dueDate {
          return (left.dueDate ?? .distantFuture) < (right.dueDate ?? .distantFuture)
        }
      case .title:
        let comparison = left.title.localizedStandardCompare(right.title)
        if comparison != .orderedSame { return comparison == .orderedAscending }
      case .important:
        if left.isImportant != right.isImportant { return left.isImportant }
      case .created: break
      }
      if left.createdAt != right.createdAt { return left.createdAt > right.createdAt }
      return left.id.uuidString < right.id.uuidString
    }
  }
}

struct FocusProject: Codable, Identifiable, Equatable {
  let id: UUID
  var title: String
  let createdAt: Date
}

// Capture attribution at session start so moves and deletions never rewrite history.
struct FocusAssignment: Codable, Equatable {
  let taskID: UUID
  let taskTitle: String
  let projectID: UUID?
  let projectTitle: String?
}
