// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "NoteMac",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(name: "NoteMac", targets: ["NoteMac"])
    ],
    dependencies: [
        .package(url: "https://github.com/krzyzanowskim/STTextView", from: "0.9.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.10.0")
    ],
    targets: [
        .executableTarget(
            name: "NoteMac",
            dependencies: [
                .product(name: "STTextView", package: "STTextView")
            ],
            path: "Sources/NoteMac",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "NoteMacTests",
            dependencies: [
                "NoteMac",
                .product(name: "Testing", package: "swift-testing")
            ],
            path: "Tests/NoteMacTests"
        )
    ]
)
