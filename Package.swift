// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "swiftdata-sectionedquery",
    platforms: [
        .macOS("14.0"),
        .iOS("17.0"),
    ],
    products: [
        .library(
            name: "SectionedQuery",
            targets: ["SectionedQuery"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-algorithms", from:"1.0.0"),
    ],
    targets: [
        .target(
            name: "SectionedQuery",
            dependencies: [
                .product(name: "Algorithms", package: "swift-algorithms"),
            ]
        ),
        .testTarget(
            name: "SectionedQueryTests",
            dependencies: ["SectionedQuery"]
        ),
    ]
)
