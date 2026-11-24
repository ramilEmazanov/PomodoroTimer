import SwiftUI

struct DurationEntryModePicker: View {
  @Binding var selection: InterfaceState.EntryMode
  @Environment(\.colorScheme) private var colorScheme

  private var dark: Bool { colorScheme == .dark }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(InterfaceState.EntryMode.allCases, id: \.self) { mode in
        Button {
          selection = mode
        } label: {
          Text(mode.rawValue)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(dark ? Color.white : Color.primary)
            .frame(maxWidth: .infinity).frame(height: 28)
            .background {
              if selection == mode {
                Capsule().fill(dark ? Color.white.opacity(0.11) : Color.white)
              }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == mode ? .isSelected : [])
      }
    }
    .padding(4)
    .frame(width: 220)
    .background {
      Capsule().fill(
        LinearGradient(
          colors: dark
            ? [Color(white: 0.205), Color(white: 0.18)]
            : [Color(white: 0.94), Color(white: 0.91)],
          startPoint: .top, endPoint: .bottom))
    }
    .overlay {
      Capsule().strokeBorder(
        LinearGradient(
          colors: dark
            ? [Color(red: 0.34, green: 0.38, blue: 0.41), Color.white.opacity(0.12)]
            : [Color.black.opacity(0.15), Color.black.opacity(0.1)],
          startPoint: .top, endPoint: .bottom), lineWidth: 1)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("Duration entry mode")
  }
}
