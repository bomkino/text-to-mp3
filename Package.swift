// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TextToMP3",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TextToMP3", targets: ["TextToMP3App"])
    ],
    targets: [
        .executableTarget(
            name: "TextToMP3App",
            resources: [
                .copy("Resources/edge_helper.py")
            ]
        )
    ]
)
