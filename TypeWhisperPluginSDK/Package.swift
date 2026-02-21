// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "TypeWhisperPluginSDK",
    platforms: [.macOS(.v15)],
    products: [
        .library(name: "TypeWhisperPluginSDK", type: .dynamic, targets: ["TypeWhisperPluginSDK"]),
    ],
    targets: [
        .target(name: "TypeWhisperPluginSDK"),
    ]
)
