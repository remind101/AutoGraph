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
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMinor(from: "4.8.0")),
        .package(url: "https://github.com/rexmas/JSONValue.git", .upToNextMinor(from: "4.2.0"))
    ],
    targets: [
        .target(
            name: "AutoGraphQL",
            dependencies: ["Alamofire", "JSONValueRX"],
            path: ".",
            sources: ["AutoGraph", "QueryBuilder", "OperationExecution"]),
        .testTarget(
            name: "AutoGraphTests",
            dependencies: ["AutoGraphQL"],
            path: "./AutoGraphTests"),
        .testTarget(
            name: "OperationExecutionTests",
            dependencies: ["AutoGraphQL"],
            path: "./OperationExecutionTests"),
        .testTarget(
            name: "QueryBuilderTests",
            dependencies: ["AutoGraphQL"],
            path: "./QueryBuilderTests"),
        ]
)
