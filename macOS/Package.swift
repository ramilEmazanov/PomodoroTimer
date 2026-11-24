// swift-tools-version: 6.2
import PackageDescription

let package = Package(
  name: "Focus",
  platforms: [.macOS(.v14)],
  products: [.executable(name: "Focus", targets: ["Focus"])],
  targets: [
    .executableTarget(
      name: "Focus",
      swiftSettings: [
        .defaultIsolation(MainActor.self),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
      ]
    ),
    .testTarget(
      name: "FocusTests", dependencies: ["Focus"],
      swiftSettings: [.defaultIsolation(MainActor.self)]),
  ]
)
