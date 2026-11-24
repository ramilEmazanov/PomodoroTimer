import SwiftUI

struct StatisticsSummary: View {
  let state: InterfaceState

  private var today: DateInterval {
    Calendar.current.dateInterval(of: .day, for: state.now)!
  }

  private var week: DateInterval {
    Calendar.current.dateInterval(of: .weekOfYear, for: state.now)!
  }

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: 16) { cards }
      VStack(spacing: 16) { cards }
    }
  }

  @ViewBuilder private var cards: some View {
    card(
      "Total Focus Time",
      seconds: state.history.focusedSeconds(in: DateInterval(start: .distantPast, end: state.now)))
    card("Focus Time of This Week", seconds: state.history.focusedSeconds(in: week))
    card("Focus Time of Today", seconds: state.history.focusedSeconds(in: today))
  }

  private func card(_ title: String, seconds: TimeInterval) -> some View {
    let minutes = max(0, Int(seconds / 60))
    let accent = Color(light: 0xE5484D, dark: 0xFF555B)
    return VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top, spacing: 10) {
        Capsule().fill(accent).frame(width: 4, height: 14).padding(.top, 4)
        Text(title).font(.system(size: 17, weight: .medium))
          .lineLimit(2).fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
      HStack(alignment: .firstTextBaseline, spacing: 3) {
        Text("\(minutes / 60)")
          .font(.system(size: 44, weight: .semibold).width(.condensed))
          .foregroundStyle(accent)
        Text("h").font(.system(size: 14)).foregroundStyle(.secondary)
        Text("\(minutes % 60)")
          .font(.system(size: 44, weight: .semibold).width(.condensed))
          .foregroundStyle(accent).padding(.leading, 4)
        Text("m").font(.system(size: 14)).foregroundStyle(.secondary)
      }
      .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
    }
    .padding(20)
    .frame(minWidth: 210, maxWidth: .infinity, minHeight: 176, alignment: .leading)
    .background(
      Color(light: 0xFFFFFF, dark: 0x1B1B23),
      in: RoundedRectangle(cornerRadius: 20)
    )
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(title)
    .accessibilityValue(FocusHistory.display(seconds))
  }
}
