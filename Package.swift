// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "QuantumWaveformApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "QuantumWaveformApp", targets: ["App"])
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-enable-experimental-concurrency"])
            ]
        )
    ]
) 
