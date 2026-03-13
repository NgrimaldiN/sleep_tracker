// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "GarminImportCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(
            name: "GarminImportCore",
            targets: ["GarminImportCore"]
        ),
    ],
    targets: [
        .target(
            name: "GarminImportCore"
        ),
        .testTarget(
            name: "GarminImportCoreTests",
            dependencies: ["GarminImportCore"]
        ),
    ]
)
