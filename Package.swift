// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "fake-gamepad",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "fake-gamepad",
            path: "Sources/FakeGamepad",
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        )
    ]
)
