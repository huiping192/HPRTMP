// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HPRTMP",
    platforms: [.iOS(.v14), .macOS(.v11)],
    products: [
        .library(
            name: "HPRTMP",
            targets: ["HPRTMP"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio", from: "2.0.0"),
    ],
    targets: [
        .target(
            name: "HPRTMP",
            dependencies: [
                .product(name: "NIO", package: "swift-nio")
            ]),
        .testTarget(
            name: "HPRTMPTests",
            dependencies: ["HPRTMP"]),
    ],
    swiftLanguageVersions: [.v5]
)
