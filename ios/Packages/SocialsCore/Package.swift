// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SocialsCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "SocialsCore", targets: ["SocialsCore"])
    ],
    dependencies: [
        .package(path: "../../../../cuanto-kit")
    ],
    targets: [
        .target(
            name: "SocialsCore",
            dependencies: [
                .product(name: "CuantoCore", package: "cuanto-kit"),
                .product(name: "CuantoNet", package: "cuanto-kit"),
            ]
        ),
        .testTarget(
            name: "SocialsCoreTests",
            dependencies: [
                "SocialsCore",
                .product(name: "CuantoTesting", package: "cuanto-kit"),
            ],
            resources: [.process("Fixtures")]
        ),
    ]
)
