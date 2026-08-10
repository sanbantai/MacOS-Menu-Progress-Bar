// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MenuProgress",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "MenuProgress", targets: ["MenuProgress"])
    ],
    targets: [
        .executableTarget(
            name: "MenuProgress",
            path: "Sources/MenuProgress"
        )
    ]
)
