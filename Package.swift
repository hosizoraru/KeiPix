// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "KeiPix",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)
    ],
    products: [
        .executable(name: "KeiPix", targets: ["KeiPix"])
    ],
    targets: [
        .executableTarget(
            name: "KeiPix",
            resources: [
                .process("Resources")
            ],
            plugins: [
                .plugin(name: "XCStringsBuilder")
            ]
        ),
        // Build-tool plugin: compiles every `.xcstrings` catalog into
        // per-locale `.lproj/<stem>.strings` via `xcrun xcstringstool compile`.
        // SwiftPM 6.2 does not run `xcstringstool` automatically, so the
        // shipping bundle would otherwise lack `.lproj` directories and every
        // locale other than the development language would silently fall back.
        .plugin(
            name: "XCStringsBuilder",
            capability: .buildTool()
        ),
        .testTarget(
            name: "KeiPixTests",
            dependencies: ["KeiPix"]
        )
    ]
)
