import SwiftUI

@main
struct FocusApp: App {
  @State private var state = InterfaceState()
  @AppStorage(InterfaceZoom.storageKey) private var zoomPercentage = 100

  var body: some Scene {
    Window("Focus", id: "main") {
      ZoomedInterface {
        WorkspaceView(state: state)
      }
      .frame(
        minWidth: 820 * InterfaceZoom.scale(for: zoomPercentage),
        minHeight: 640 * InterfaceZoom.scale(for: zoomPercentage)
      )
    }
    .defaultSize(width: 1180, height: 820)
    .windowStyle(.hiddenTitleBar)
    .windowResizability(.contentMinSize)
    .commands {
      CommandGroup(replacing: .newItem) {}
      CommandGroup(after: .toolbar) {
        Button("Zoom In") { zoomPercentage = InterfaceZoom.clamped(zoomPercentage + 5) }
          .keyboardShortcut("+")
          .disabled(zoomPercentage >= 125)
        Button("Zoom Out") { zoomPercentage = InterfaceZoom.clamped(zoomPercentage - 5) }
          .keyboardShortcut("-")
          .disabled(zoomPercentage <= 80)
        Button("Actual Size") { zoomPercentage = 100 }
          .keyboardShortcut("0")
      }
    }
  }
}
