// swift-tools-version:5.10
//
// bar-helper — native macOS menu bar manager.
//
// Built as a SwiftPM executable so it can be built and run from the command
// line. The product baseline per docs/requirements.md (REQ-X01) is macOS 16+
// with macOS 26 "Tahoe" as the primary validation target. The user-facing
// launch gate lives in Resources/Info.plist (LSMinimumSystemVersion 16.0);
// the SwiftPM deployment target is kept at a literal SDK version (.v14) to
// avoid the toolchain's 16.0->26.0 deployment-version override warning while
// the .app's plist remains the authoritative minimum. Tools version 5.10
// keeps the AppKit integration in the Swift 5 language mode (no
// strict-concurrency churn) while still compiling under Swift 6.
import PackageDescription

let package = Package(
    name: "bar-helper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "bar-helper", targets: ["BarHelper"])
    ],
    targets: [
        .executableTarget(
            name: "BarHelper",
            path: "Sources/BarHelper"
        ),
        .testTarget(
            name: "BarHelperTests",
            dependencies: ["BarHelper"],
            path: "Tests/BarHelperTests"
        )
    ]
)
