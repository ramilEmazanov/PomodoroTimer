import SwiftUI

struct WorkspaceView: View {
  @State private var state = InterfaceState()
  @Environment(\.colorScheme) private var systemScheme

  var body: some View {
    HStack(spacing: 0) {
      sidebar
      Divider()
      ScrollView {
        Group {
          switch state.section {
          case .home: HomeView(state: state)
          case .timer: TimersView(state: state)
          case .statistics, .settings: placeholder
          }
        }
        .padding(40)
        .frame(maxWidth: 1120)
        .frame(maxWidth: .infinity)
      }
      .background(Color.workspace)
    }
    .background(Color.panel)
    .preferredColorScheme(state.dark ? .dark : .light)
    .tint(.blue)
    .onAppear { state.dark = systemScheme == .dark }
    .alert("Reset timer?", isPresented: $state.showReset) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive) { state.reset() }
    } message: {
      Text("Return to duration setup? This interface preview does not save sessions.")
    }
  }

  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Focus").font(.system(size: 22, weight: .semibold))
        .padding(.top, 36).padding(.horizontal, 12).padding(.bottom, 32)
      Text("Workspace").font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary).padding(.horizontal, 12).padding(.bottom, 12)
      ForEach(InterfaceState.Section.allCases) { section in
        Button {
          state.section = section
        } label: {
          HStack(spacing: 12) {
            Image(systemName: section.symbol).font(.system(size: 19)).frame(width: 24)
            Text(section.rawValue).font(
              .system(size: 15, weight: state.section == section ? .semibold : .regular))
            Spacer(minLength: 0)
          }
          .padding(.horizontal, 12).frame(height: 42)
          .background(
            state.section == section ? Color.selection : .clear,
            in: RoundedRectangle(cornerRadius: 11)
          )
          .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain).padding(.bottom, 4)
        .accessibilityAddTraits(state.section == section ? .isSelected : [])
      }
      Toggle("Dark mode", isOn: $state.dark).toggleStyle(.switch)
        .font(.system(size: 13)).padding(.horizontal, 12).padding(.top, 28)
      Spacer(minLength: 40)
      VStack(alignment: .leading, spacing: 8) {
        Text("Prototype preview").font(.system(size: 11, weight: .medium)).foregroundStyle(
          .secondary)
        Menu {
          ForEach(InterfaceState.Preview.allCases) { preview in
            Button(preview.rawValue) { state.preview(preview) }
          }
        } label: {
          HStack {
            Text("Choose a state")
            Spacer()
            Image(systemName: "chevron.up.chevron.down")
          }
        }
        .menuStyle(.borderlessButton)
        .padding(10).background(Color.selection, in: RoundedRectangle(cornerRadius: 8))
        Text("Interface preview · No data saved")
          .font(.system(size: 10)).foregroundStyle(.secondary)
      }
      .padding(.horizontal, 6).padding(.bottom, 24)
    }
    .padding(.horizontal, 18).frame(width: 232)
  }

  private var placeholder: some View {
    let stats = state.section == .statistics
    return VStack(spacing: 30) {
      PageHeading(
        title: stats ? "Statistics" : "Settings",
        subtitle: stats ? "Your focus session history and trends." : "Personalize your workspace.")
      EmptyPanel(
        symbol: stats ? "chart.bar" : "gearshape", title: "Coming soon",
        message: stats
          ? "Detailed statistics will be available in a future update."
          : "More settings will be available in a future update.")
    }
  }
}
