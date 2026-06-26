// swift-tools-version:5.10
//
// bar-helper — native macOS menu bar manager.
//
// Built as a SwiftPM executable so it can be built and run from the command
// line. The product baseline per docs/requirements.md (REQ-X01) is macOS 16+
// with macOS 26 "Tahoe" as the primary validation target; the package
// deployment target is set to macOS 14 so it builds against the installed
// SDK while remaining broadly compatible. Tools version 5.10 keeps the AppKit
// integration in the Swift 5 language mode (no strict-concurrency churn) while
// still compiling under the installed Swift 6 toolchain.
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
