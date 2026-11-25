import Foundation

enum FocusChartPeriod: String, CaseIterable, Identifiable {
  case daily = "Daily"
  case weekly = "Weekly"
  case monthly = "Monthly"
  case yearly = "Yearly"

  var id: Self { self }

  var component: Calendar.Component {
    switch self {
    case .daily: .day
    case .weekly: .weekOfYear
    case .monthly: .month
    case .yearly: .year
    }
  }

  var count: Int {
    switch self {
    case .daily: 7
    case .weekly: 8
    case .monthly: 12
    case .yearly: 5
    }
  }

  var rangeLabel: String {
    switch self {
    case .daily: "Last 7 days"
    case .weekly: "Last 8 weeks"
    case .monthly: "Last 12 months"
    case .yearly: "Last 5 years"
    }
  }

  func intervals(endingAt date: Date, calendar: Calendar = .current) -> [DateInterval] {
    guard let current = calendar.dateInterval(of: component, for: date) else { return [] }
    return (0..<count).reversed().compactMap { offset in
      guard let start = calendar.date(byAdding: component, value: -offset, to: current.start) else {
        return nil
      }
      return calendar.dateInterval(of: component, for: start)
    }
  }
}
