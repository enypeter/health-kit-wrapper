// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "health_kit_wrapper",
    platforms: [
        .iOS("13.0")
    ],
    products: [
        .library(name: "health-kit-wrapper", targets: ["health_kit_wrapper"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "health_kit_wrapper",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("HealthKit")
            ]
        )
    ]
)
