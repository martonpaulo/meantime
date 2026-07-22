// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "Meantime",
    platforms: [
        .macOS(.v26),
    ],
    dependencies: [
        // The single approved runtime dependency: automatic updates for the
        // direct-download (Developer ID) build. Never used by MeantimeKit.
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.6.0"),
    ],
    targets: [
        // Pure, dependency-free domain: models, formatting, timing math, and the
        // preferences contract. Fully unit-tested; imports Foundation only.
        .target(
            name: "MeantimeKit",
            path: "Sources/MeantimeKit"
        ),
        // The app: menu-bar surface, SwiftUI panel and settings, lifecycle,
        // login item, and Sparkle. Renders prepared state from MeantimeKit.
        .executableTarget(
            name: "Meantime",
            dependencies: [
                "MeantimeKit",
                .product(name: "Sparkle", package: "Sparkle"),
            ],
            path: "Sources/Meantime",
            linkerSettings: [
                // The packaged .app embeds Sparkle.framework in Contents/Frameworks.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        .testTarget(
            name: "MeantimeKitTests",
            dependencies: ["MeantimeKit"],
            path: "Tests/MeantimeKitTests"
        ),
    ]
)
