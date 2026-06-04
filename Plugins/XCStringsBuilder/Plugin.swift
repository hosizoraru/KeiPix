import Foundation
import PackagePlugin

/// SwiftPM build-tool plugin that compiles every `.xcstrings` catalog into
/// per-locale `.lproj/<catalog>.strings` files at build time.
///
/// SwiftPM 6.2 raw-copies `.xcstrings` files into the resource bundle but
/// does not invoke `xcstringstool` automatically. Without this plugin the
/// shipping bundle has no `.lproj` directories, so `Bundle.localizedString`
/// falls through to the development-language source string and any locale
/// other than `en` is dead.
///
/// `xcstringstool` is not exposed through the plugin tool registry, so we
/// invoke it directly via `/usr/bin/xcrun xcstringstool compile`. The
/// `compile` subcommand emits `<lang>.lproj/<stem>.strings` into the
/// supplied output directory, which SwiftPM then picks up as bundle
/// resources.
@main
struct XCStringsBuilder: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let sourceModule = target as? SourceModuleTarget else { return [] }
        let inputs = sourceModule.sourceFiles.filter { $0.url.pathExtension == "xcstrings" }
        guard inputs.isEmpty == false else { return [] }

        let outDir = context.pluginWorkDirectoryURL.appendingPathComponent("xcstrings-out")

        return inputs.map { file in
            .prebuildCommand(
                displayName: "Compile \(file.url.lastPathComponent)",
                executable: URL(fileURLWithPath: "/usr/bin/xcrun"),
                arguments: [
                    "xcstringstool",
                    "compile",
                    "--output-directory", outDir.path,
                    file.url.path
                ],
                outputFilesDirectory: outDir
            )
        }
    }
}
