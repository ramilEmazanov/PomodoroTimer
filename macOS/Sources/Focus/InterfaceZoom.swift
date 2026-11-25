import SwiftUI

enum InterfaceZoom {
  static let storageKey = "interfaceZoomPercent"
  static let percentages = Array(stride(from: 80, through: 125, by: 5))

  static func clamped(_ percentage: Int) -> Int {
    min(125, max(80, percentage))
  }

  static func scale(for percentage: Int) -> CGFloat {
    CGFloat(clamped(percentage)) / 100
  }
}

struct ZoomedInterface<Content: View>: View {
  @AppStorage(InterfaceZoom.storageKey) private var percentage = 100
  @ViewBuilder var content: Content

  var body: some View {
    GeometryReader { geometry in
      let scale = InterfaceZoom.scale(for: percentage)
      content
        .frame(width: geometry.size.width / scale, height: geometry.size.height / scale)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
    }
  }
}
