// swift-tools-version: 6.0
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
        .package(url: "https://github.com/apple/swift-nio", from: "2.70.0"),
        .package(url: "https://github.com/apple/swift-nio-ssl", from: "2.27.0"),
    ],
    targets: [
        .target(
            name: "HPRTMP",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOSSL", package: "swift-nio-ssl")
            ]),
        .testTarget(
            name: "HPRTMPTests",
            dependencies: ["HPRTMP"]),
    ]
)
