import SwiftUI

struct WorkspaceView: View {
  @Bindable var state: InterfaceState
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(InterfaceZoom.storageKey) private var zoomPercentage = 100

  var body: some View {
    HStack(spacing: 0) {
      sidebar
      Divider()
      VStack(spacing: 0) {
        if let error = state.storageError {
          Surface {
            VStack(alignment: .leading, spacing: 12) {
              Label("Unable to save data", systemImage: "exclamationmark.triangle").font(.headline)
              Text(error).font(.callout).foregroundStyle(.secondary)
              Button("Retry storage") { state.retryStorage() }.buttonStyle(ActionStyle())
            }.frame(maxWidth: .infinity, alignment: .leading)
          }.padding(24)
        }
        if state.section == .tasks {
          TasksView(state: state).disabled(!state.loaded)
        } else if state.section == .projects {
          ProjectsView(state: state).disabled(!state.loaded)
        } else {
          ScrollView {
            Group {
              switch state.section {
              case .home: HomeView(state: state)
              case .timer: TimersView(state: state)
              case .statistics: StatisticsView(state: state)
              case .settings: settings
              case .tasks, .projects: EmptyView()
              }
            }
            .disabled(!state.loaded)
            .padding(40)
            .frame(maxWidth: 1120)
            .frame(maxWidth: .infinity)
          }
        }
      }
      .background(Color.workspace)
    }
    .background(Color.panel)
    .preferredColorScheme(state.dark ? .dark : .light)
    .tint(.blue)
    .task {
      while !Task.isCancelled {
        state.refresh()
        do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
      }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { state.refresh() }
    }
    .alert("Reset timer?", isPresented: $state.showReset) {
      Button("Cancel", role: .cancel) {}
      Button("Reset", role: .destructive) { state.reset() }
    } message: {
      Text(
        "Stop this session and return to duration setup? Time already focused will be saved in your history."
      )
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
      Label(
        state.storageError == nil ? "Saved on this Mac" : "Storage needs attention",
        systemImage: state.storageError == nil ? "internaldrive" : "exclamationmark.triangle"
      )
      .font(.system(size: 11)).foregroundStyle(.secondary)
      .padding(.horizontal, 6).padding(.bottom, 24)
    }
    .padding(.horizontal, 18).frame(width: 232)
  }

  private var settings: some View {
    VStack(alignment: .leading, spacing: 24) {
      PageHeading(title: "Settings", subtitle: "Personalize your workspace.")
      Surface {
        VStack(alignment: .leading, spacing: 20) {
          Toggle("Dark mode", isOn: $state.dark).toggleStyle(.switch)
          Divider()
          HStack {
            Picker("Interface scale", selection: $zoomPercentage) {
              ForEach(InterfaceZoom.percentages, id: \.self) { percentage in
                Text("\(percentage)%").tag(percentage)
              }
            }
            .pickerStyle(.menu)
            Button("Reset") { zoomPercentage = 100 }
              .disabled(zoomPercentage == 100)
          }
          Text("Zoom with ⌘+ and ⌘−. Return to 100% with ⌘0.")
            .font(.system(size: 12)).foregroundStyle(.secondary)
          Divider()
          Label("Local storage", systemImage: "internaldrive").font(.headline)
          Text("Your sessions, timer and preferences are saved automatically on this Mac.")
            .foregroundStyle(.secondary)
          Text(SQLiteFocusStore.defaultURL.path).font(.system(size: 12)).textSelection(.enabled)
          Text(
            "The timer continues during sleep and while the app is closed. Pause it to stop tracking time."
          )
          .font(.system(size: 12)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }
}
