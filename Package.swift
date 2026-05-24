// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "KeiPix",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "KeiPix", targets: ["KeiPix"])
    ],
    targets: [
        .executableTarget(
            name: "KeiPix",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "KeiPixTests",
            dependencies: ["KeiPix"]
        )
    ]
)
