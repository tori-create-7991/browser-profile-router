// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "BrowserProfileRouter",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "BrowserProfileRouter", targets: ["BrowserProfileRouter"]),
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.3"),
    ],
    targets: [
        .executableTarget(
            name: "BrowserProfileRouter",
            dependencies: ["Yams"]
        ),
        .testTarget(name: "BrowserProfileRouterTests", dependencies: ["BrowserProfileRouter"]),
    ]
)
