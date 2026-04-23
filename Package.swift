// swift-tools-version: 6.0
import PackageDescription

// Test-only package that reuses the app's non-UI source directories.
// The Xcode project (Kairo.xcodeproj) remains the source of truth for app builds;
// this package exists so `swift test` can exercise model + service logic without
// the Xcode test target setup.
let package = Package(
    name: "KairoCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    targets: [
        .target(
            name: "KairoCore",
            path: "Kairo",
            exclude: [
                "Assets.xcassets",
                "ContentView.swift",
                "Features",
                "Info.plist",
                "Kairo.entitlements",
                "KairoApp.swift",
            ],
            sources: [
                "Models",
                "Services",
                "Extensions",
                "LiveActivity",
            ]
        ),
        .testTarget(
            name: "KairoCoreTests",
            dependencies: ["KairoCore"],
            path: "Tests/KairoCoreTests"
        ),
    ]
)
