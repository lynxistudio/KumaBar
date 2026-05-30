// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KumaBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "KumaBar", targets: ["KumaBar"])
    ],
    targets: [
        .executableTarget(
            name: "KumaBar",
            path: "Sources/KumaBar"
        ),
        .testTarget(
            name: "KumaBarTests",
            dependencies: ["KumaBar"],
            path: "Tests/KumaBarTests"
        )
    ],
    swiftLanguageModes: [.v6]
)
