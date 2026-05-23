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
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", .upToNextMajor(from: "0.9.20"))
    ],
    targets: [
        .executableTarget(
            name: "KeiPix",
            dependencies: [
                "ZIPFoundation"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
