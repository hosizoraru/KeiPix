// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "KeiPix",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "KeiPix", targets: ["KeiPix"]),
        // CLI tool that regenerates `zh-Hant.lproj` and `ja.lproj` from
        // the canonical `zh-Hans` / `en` sources. Run on demand with
        // `swift run LocalizationGenerator`; the output `.strings`
        // files are committed alongside the rest of the resources, so
        // the shipping app target has zero dependency on this tool.
        .executable(name: "LocalizationGenerator", targets: ["LocalizationGenerator"])
    ],
    targets: [
        .executableTarget(
            name: "KeiPix",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "LocalizationGenerator",
            path: "Sources/LocalizationGenerator"
        ),
        .testTarget(
            name: "KeiPixTests",
            dependencies: ["KeiPix"]
        ),
        .testTarget(
            name: "LocalizationGeneratorTests",
            dependencies: ["LocalizationGenerator"]
        )
    ]
)
