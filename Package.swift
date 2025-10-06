// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SourceryBuildPlugin",
    platforms: [.iOS(.v13), .macOS(.v10_15), .watchOS(.v6), .tvOS(.v13)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .plugin(name: "SourceryBuildPlugin", targets: ["SourceryBuildPlugin"]),
    ],
    dependencies: [],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .plugin(
            name: "SourceryBuildPlugin",
            capability: .buildTool(),
            dependencies: [
                .target(name: "SourceryBinary")
            ]
        ),
        .binaryTarget(
            name: "SourceryBinary",
            url: "https://github.com/krzysztofzablocki/Sourcery/releases/download/null/sourcery-null.artifactbundle.zip",
            checksum: "0019dfc4b32d63c1392aa264aed2253c1e0c2fb09216f8e2cc269bbfb8bb49b5"
        ),
    ]
)
