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
        )
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(url: "https://github.com/realm/SwiftLint", from: "0.52.2")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "HPRTMP",
            dependencies: [],
            plugins: [.plugin(name: "SwiftLintPlugin", package: "SwiftLint")]),
        .testTarget(
            name: "HPRTMPTests",
            dependencies: ["HPRTMP"])
    ]
)
