// swift-tools-version:5.1.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AutoGraph",
    platforms: [
        .macOS(.v10_12),
        .iOS(.v10)
    ],
    products: [
        .library(
            name: "AutoGraphQL",
            targets: ["AutoGraphQL"]),
        ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMinor(from: "5.0.2")),
        .package(url: "https://github.com/rexmas/JSONValue.git", .upToNextMinor(from: "6.2.0"))
    ],
    targets: [
        .target(
            name: "AutoGraphQL",
            dependencies: ["Alamofire", "JSONValueRX"],
            path: ".",
            sources: ["AutoGraph", "QueryBuilder"]),
        .testTarget(
            name: "AutoGraphTests",
            dependencies: ["AutoGraphQL"],
            path: "./AutoGraphTests"),
        .testTarget(
            name: "QueryBuilderTests",
            dependencies: ["AutoGraphQL"],
            path: "./QueryBuilderTests"),
        ]
)
