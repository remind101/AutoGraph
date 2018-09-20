// swift-tools-version:4.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AutoGraph",
    products: [
        .library(
            name: "AutoGraphQL",
            targets: ["AutoGraphQL"]),
        ],
    dependencies: [
        .package(url: "https://github.com/rexmas/Crust.git", .upToNextMinor(from: "0.9.2")),
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMinor(from: "4.7.3"))
    ],
    targets: [
        .target(
            name: "AutoGraphQL",
            dependencies: ["Crust", "Alamofire"],
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
