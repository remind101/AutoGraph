// swift-tools-version:5.9.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AutoGraph",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "AutoGraphQL",
            targets: ["AutoGraphQL"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMinor(from: "5.8.0")),
        .package(url: "https://github.com/rexmas/JSONValue.git", .upToNextMinor(from: "8.0.0")),
        .package(url: "https://github.com/daltoniam/Starscream.git", .exact("4.0.8"))
    ],
    targets: [
        .target(
            name: "AutoGraphQL",
            dependencies: [
                "Alamofire",
                .product(name: "JSONValueRX", package: "JSONValue"),
                "Starscream"
            ],
            path: ".",
            exclude: ["AutoGraph/Info.plist", "QueryBuilder/Info.plist"],
            sources: ["AutoGraph", "QueryBuilder"]
        ),
        .testTarget(
            name: "AutoGraphTests",
            dependencies: ["AutoGraphQL"],
            path: "./AutoGraphTests"
        ),
        .testTarget(
            name: "QueryBuilderTests",
            dependencies: ["AutoGraphQL"],
            path: "./QueryBuilderTests"
        )
    ]
)

