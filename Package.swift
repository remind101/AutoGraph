// swift-tools-version:4.0
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
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "AutoGraphQL",
            dependencies: ["Crust", "Alamofire"],
            path: ".",
            sources: ["AutoGraph", "QueryBuilder"]),
//        .target(
//            name: "QueryBuilder",
//            path: "./QueryBuilder"),
        .testTarget(
            name: "AutoGraphTests",
            dependencies: ["AutoGraphQL"],
            path: "./AutoGraphTests"),
//        .testTarget(
//            name: "QueryBuilderTests",
//            dependencies: ["QueryBuilder"],
//            path: "./QueryBuilderTests"),
        ]
)