// swift-tools-version:5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "QwantumWaveform",
    platforms: [
        .macOS(.v13),  // Using macOS 13 which is available in PackageDescription 5.8
        .iOS(.v16),
    ],
    products: [
        .executable(
            name: "QwantumWaveform",
            targets: ["QwantumWaveform"]
        )
    ],
    dependencies: [
        // Add any external dependencies here if needed
    ],
    targets: [
        .executableTarget(
            name: "QwantumWaveform",
            dependencies: [
                "QwantumCore",
                "QwantumUI",
                "QwantumRendering",
                "QwantumModels",
            ],
            path: "QwantumWaveform/Sources/App",
            exclude: ["Info.plist"]
        ),
        .target(
            name: "QwantumCore",
            dependencies: [
                "QwantumModels"
            ],
            path: "QwantumWaveform/Sources/Core"
        ),
        .target(
            name: "QwantumUI",
            dependencies: [
                "QwantumCore",
                "QwantumModels",
            ],
            path: "QwantumWaveform/Sources/UI"
        ),
        .target(
            name: "QwantumRendering",
            dependencies: [
                "QwantumCore",
                "QwantumModels",
            ],
            path: "QwantumWaveform/Sources/Rendering",
            resources: [
                .process("Shaders")
            ]
        ),
        .target(
            name: "QwantumModels",
            dependencies: [],
            path: "QwantumWaveform/Sources/Models"
        ),
        .testTarget(
            name: "QwantumWaveformTests",
            dependencies: [
                "QwantumCore",
                "QwantumUI",
                "QwantumRendering",
                "QwantumModels",
            ],
            path: "QwantumWaveformTests"
        ),
        .testTarget(
            name: "QwantumWaveformUITests",
            dependencies: ["QwantumWaveform"],
            path: "QwantumWaveformUITests"
        ),
    ]
)
