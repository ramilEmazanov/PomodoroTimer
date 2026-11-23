import SwiftUI

extension Color {
  static let workspace = Color(light: 0xF5F5F7, dark: 0x1C1C1E)
  static let panel = Color(light: 0xFFFFFF, dark: 0x2C2C2E)
  static let selection = Color(light: 0xF1F1F1, dark: 0x3A3A3C)

  init(light: UInt32, dark: UInt32) {
    self.init(
      nsColor: NSColor(name: nil) { appearance in
        let hex = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        return NSColor(
          red: CGFloat((hex >> 16) & 255) / 255,
          green: CGFloat((hex >> 8) & 255) / 255,
          blue: CGFloat(hex & 255) / 255, alpha: 1
        )
      })
  }
}

struct Surface<Content: View>: View {
  @ViewBuilder var content: Content
  var body: some View {
    content.padding(24)
      .background(Color.panel, in: RoundedRectangle(cornerRadius: 22))
      .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.primary.opacity(0.05)))
  }
}

struct ActionStyle: ButtonStyle {
  var prominent = true
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 14, weight: .semibold))
      .padding(.horizontal, 20).frame(minHeight: 42)
      .foregroundStyle(prominent ? Color.white : Color.primary)
      .background(
        prominent ? Color.accentColor : Color.selection, in: RoundedRectangle(cornerRadius: 12)
      )
      .opacity(configuration.isPressed ? 0.7 : 1)
      .contentShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct PageHeading: View {
  let title: String
  var subtitle: String? = nil
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.system(size: 36, weight: .bold)).tracking(-1)
        .accessibilityAddTraits(.isHeader)
      if let subtitle { Text(subtitle).font(.system(size: 15)).foregroundStyle(.secondary) }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct EmptyPanel: View {
  let symbol: String
  let title: String
  let message: String
  var action: (() -> Void)? = nil
  var body: some View {
    Surface {
      VStack(spacing: 16) {
        Image(systemName: symbol).font(.system(size: 30, weight: .light))
          .foregroundStyle(.blue).frame(width: 64, height: 64)
          .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        Text(title).font(.system(size: 22, weight: .semibold))
        Text(message).foregroundStyle(.secondary).multilineTextAlignment(.center)
        if let action {
          Button(action: action) { Label("Start timer", systemImage: "play.fill") }
            .buttonStyle(ActionStyle()).padding(.top, 8)
        }
      }
      .frame(maxWidth: .infinity, minHeight: 300)
    }
  }
}
