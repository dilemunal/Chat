// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EnterpriseChat",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "EnterpriseChat",
            targets: ["EnterpriseChat"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
    ],
    targets: [
        .executableTarget(
            name: "EnterpriseChat",
            dependencies: ["Starscream"],
            path: "."
        )
    ]
)
