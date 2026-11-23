import SwiftUI

@main
struct FocusApp: App {
  var body: some Scene {
    Window("Focus", id: "main") {
      WorkspaceView()
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
