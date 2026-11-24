import SwiftUI

@main
struct FocusApp: App {
  @State private var state = InterfaceState()
  var body: some Scene {
    Window("Focus", id: "main") {
      WorkspaceView(state: state)
        .frame(minWidth: 820, minHeight: 640)
    }
    .defaultSize(width: 1180, height: 820)
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentMinSize)
    .commands {
      CommandGroup(replacing: .newItem) {}
    }
  }
}
