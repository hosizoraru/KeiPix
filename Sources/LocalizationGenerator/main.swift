import Foundation

/// Regenerate `zh-Hant.lproj/Localizable.strings` and
/// `ja.lproj/Localizable.strings` from the canonical `zh-Hans` and
/// `en` sources.
///
/// Layout assumptions:
/// - The package root contains
///   `Sources/KeiPix/Resources/{en,zh-Hans,zh-Hant,ja}.lproj/`.
/// - The current working directory is the package root, which is what
///   `swift run` provides by default.
///
/// Run with `swift run LocalizationGenerator` whenever the canonical
/// sources change. The output `.strings` files are committed alongside
/// the sources so the shipping app target has zero dependency on this
/// tool — it's a maintenance utility, not a build step.
enum LocalizationGenerator {
    static func main() {
        let arguments = CommandLine.arguments
        let packageRootArgument = arguments.dropFirst().first
        let packageRoot: URL = {
            if let path = packageRootArgument {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        }()
        let resourcesRoot = packageRoot
            .appendingPathComponent("Sources", isDirectory: true)
            .appendingPathComponent("KeiPix", isDirectory: true)
            .appendingPathComponent("Resources", isDirectory: true)

        let zhHans = resourcesRoot
            .appendingPathComponent("zh-Hans.lproj", isDirectory: true)
            .appendingPathComponent("Localizable.strings")
        let en = resourcesRoot
            .appendingPathComponent("en.lproj", isDirectory: true)
            .appendingPathComponent("Localizable.strings")

        guard let zhHansContents = try? String(contentsOf: zhHans, encoding: .utf8) else {
            FileHandle.standardError.write(Data("Unable to read \(zhHans.path)\n".utf8))
            exit(1)
        }
        guard let enContents = try? String(contentsOf: en, encoding: .utf8) else {
            FileHandle.standardError.write(Data("Unable to read \(en.path)\n".utf8))
            exit(1)
        }
        let zhHansFile = StringsFile.parse(contents: zhHansContents)
        let enFile = StringsFile.parse(contents: enContents)

        let zhHantFile = generateTraditionalChinese(from: zhHansFile)
        let japaneseFile = generateJapanese(from: enFile)

        let zhHantOutput = resourcesRoot
            .appendingPathComponent("zh-Hant.lproj", isDirectory: true)
            .appendingPathComponent("Localizable.strings")
        let japaneseOutput = resourcesRoot
            .appendingPathComponent("ja.lproj", isDirectory: true)
            .appendingPathComponent("Localizable.strings")

        write(file: zhHantFile, to: zhHantOutput, header: zhHantHeader)
        write(file: japaneseFile, to: japaneseOutput, header: japaneseHeader)

        let zhHantCovered = zhHantFile.entries.count
        let jaCurated = japaneseFile.entries.filter { entry in
            JapaneseTranslations.translation(for: entry.key) != nil
        }.count
        let jaTotal = japaneseFile.entries.count
        print("Wrote zh-Hant: \(zhHantCovered) entries")
        print("Wrote ja: \(jaCurated) curated / \(jaTotal) total (English fallback for the rest)")
    }

    /// Convert simplified-Chinese entries to traditional Chinese
    /// in-place. Keys stay in English so the existing call sites don't
    /// need to change.
    static func generateTraditionalChinese(from source: StringsFile) -> StringsFile {
        var converted: [(String, String)] = []
        converted.reserveCapacity(source.entries.count)
        for entry in source.entries {
            let value = SimplifiedToTraditional.convert(entry.value)
            converted.append((entry.key, value))
        }
        return StringsFile(entries: converted)
    }

    /// Apply curated Japanese translations on top of the English
    /// source. Keys missing from the curated dictionary fall through
    /// to the English value so the bundle still resolves them.
    static func generateJapanese(from source: StringsFile) -> StringsFile {
        var translated: [(String, String)] = []
        translated.reserveCapacity(source.entries.count)
        for entry in source.entries {
            let value = JapaneseTranslations.translation(for: entry.key) ?? entry.value
            translated.append((entry.key, value))
        }
        return StringsFile(entries: translated)
    }

    private static func write(file: StringsFile, to url: URL, header: String) {
        let directory = url.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let output = file.render(header: header)
            try output.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            FileHandle.standardError.write(Data("Failed to write \(url.path): \(error)\n".utf8))
            exit(1)
        }
    }

    private static let zhHantHeader = """
    Generated by `swift run LocalizationGenerator`.
    Source: Sources/KeiPix/Resources/zh-Hans.lproj/Localizable.strings
    Do not edit by hand — regenerate after editing the zh-Hans source.
    """

    private static let japaneseHeader = """
    Generated by `swift run LocalizationGenerator`.
    Source: Sources/KeiPix/Resources/en.lproj/Localizable.strings
    Curated dictionary: Sources/LocalizationGenerator/JapaneseTranslations.swift
    Do not edit by hand — regenerate after updating sources or curated translations.
    """
}

LocalizationGenerator.main()
