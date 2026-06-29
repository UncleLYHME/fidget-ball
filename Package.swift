// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "fidget-ball",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "FidgetBall", targets: ["FidgetBall"])
    ],
    targets: [
        .executableTarget(
            name: "FidgetBall",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
