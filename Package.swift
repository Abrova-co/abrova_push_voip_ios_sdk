// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "AbrovaPushVoip",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "AbrovaPushVoip",
            targets: ["AbrovaPushVoip"]
        ),
    ],
    targets: [
        .target(
            name: "AbrovaPushVoip",
            path: "Sources"
        ),
    ]
)
