// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "AgentOre",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "AgentOreCore", targets: ["AgentOreCore"]),
        .executable(name: "AgentOre", targets: ["AgentOreApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/web3swift-team/web3swift.git", exact: "3.3.2")
    ],
    targets: [
        .target(
            name: "AgentOreCore",
            dependencies: [.product(name: "web3swift", package: "web3swift")]
        ),
        .executableTarget(
            name: "AgentOreApp",
            dependencies: ["AgentOreCore"]
        ),
        .testTarget(
            name: "AgentOreAppTests",
            dependencies: ["AgentOreCore"]
        )
    ]
)
