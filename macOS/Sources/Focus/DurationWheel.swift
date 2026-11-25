import SwiftUI

struct DurationWheel: View {
  @Binding var text: String
  let maximum: Int
  let label: String
  let unit: String
  @State private var position: Int?

  var body: some View {
    HStack(spacing: 2) {
      ScrollView(.vertical) {
        LazyVStack(spacing: 0) {
          ForEach(0...maximum, id: \.self) { value in
            Text("\(value)")
              .font(.system(size: 28, weight: .regular, design: .rounded))
              .monospacedDigit()
              .foregroundStyle(value == position ? Color.primary : Color.secondary)
              .frame(maxWidth: .infinity, alignment: .trailing)
              .padding(.trailing, 2).frame(height: 40)
              .contentShape(Rectangle())
              .onTapGesture { position = value }
              .id(value)
          }
        }
        .scrollTargetLayout()
      }
      .safeAreaPadding(.vertical, 80)
      .scrollIndicators(.hidden)
      .scrollTargetBehavior(.viewAligned)
      .scrollPosition(id: $position, anchor: .center)
      .frame(width: 66, height: 200)
      .mask(
        LinearGradient(
          stops: [
            .init(color: .clear, location: 0), .init(color: .black, location: 0.3),
            .init(color: .black, location: 0.7), .init(color: .clear, location: 1),
          ], startPoint: .top, endPoint: .bottom))
      Text(unit).font(.system(size: 18)).frame(width: 32, alignment: .leading)
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(label)
    .accessibilityValue("\(Int(text) ?? 0)")
    .accessibilityAdjustableAction { direction in
      let value = Int(text) ?? 0
      switch direction {
      case .increment: position = min(maximum, value + 1)
      case .decrement: position = max(0, value - 1)
      @unknown default: break
      }
    }
    .onAppear { position = min(maximum, max(0, Int(text) ?? 0)) }
    .onChange(of: position) { _, value in
      if let value { text = String(format: "%02d", value) }
    }
    .onChange(of: text) { _, value in
      let number = min(maximum, max(0, Int(value) ?? 0))
      if position != number { position = number }
    }
  }
}
