import Foundation

/// Minimal `.strings` reader/writer. We don't shell out to `plutil`
/// because the `.strings` format SwiftPM ships is the legacy
/// pre-Xcode-15 NSPropertyList variant — `"key" = "value";` per line —
/// not the newer `.xcstrings` JSON. Reading and writing it as plain
/// UTF-8 keeps the generator free of plist machinery.
///
/// The parser tolerates blank lines and `// ...` line comments so
/// future maintainers can group sections in the canonical `zh-Hans`
/// source without breaking generation.
struct StringsFile {
    /// Ordered entries so the generated output preserves the source
    /// file's grouping. Dictionaries would scramble the order on
    /// re-serialise, which would noise up every diff.
    var entries: [(key: String, value: String)]

    init(entries: [(key: String, value: String)] = []) {
        self.entries = entries
    }

    static func parse(contents: String) -> StringsFile {
        var entries: [(String, String)] = []
        for rawLine in contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("//") || line.hasPrefix("/*") {
                continue
            }
            guard let parsed = parseEntry(line) else { continue }
            entries.append(parsed)
        }
        return StringsFile(entries: entries)
    }

    /// Renders the file back to the canonical `"key" = "value";`
    /// format. Header comment is opt-in so the generator can mark
    /// produced files as machine-generated.
    func render(header: String? = nil) -> String {
        var output = ""
        if let header {
            for line in header.split(separator: "\n", omittingEmptySubsequences: false) {
                output.append("// \(line)\n")
            }
            output.append("\n")
        }
        for entry in entries {
            let key = Self.escape(entry.key)
            let value = Self.escape(entry.value)
            output.append("\"\(key)\" = \"\(value)\";\n")
        }
        return output
    }

    /// Lookup helper so the generator can fall back to the source
    /// value when the target language has no curated translation yet.
    func value(for key: String) -> String? {
        entries.first(where: { $0.key == key })?.value
    }

    var keys: [String] { entries.map(\.key) }

    // MARK: - Parsing

    /// Parse one canonical line. Apple's `genstrings` always emits
    /// `"key" = "value";` with the trailing semicolon, so we accept
    /// only that exact shape and skip anything that doesn't conform.
    private static func parseEntry(_ line: String) -> (String, String)? {
        guard line.hasSuffix(";") else { return nil }
        let body = String(line.dropLast())
        // Find the unescaped `=` between the two double-quoted halves.
        guard let firstQuoteRange = body.range(of: "\""),
              let assignRange = body.range(of: "=", range: firstQuoteRange.upperBound..<body.endIndex)
        else {
            return nil
        }
        let leftHalf = body[..<assignRange.lowerBound].trimmingCharacters(in: .whitespaces)
        let rightHalf = body[assignRange.upperBound...].trimmingCharacters(in: .whitespaces)

        guard let key = stripQuotes(leftHalf), let value = stripQuotes(rightHalf) else {
            return nil
        }
        return (unescape(key), unescape(value))
    }

    private static func stripQuotes(_ token: String) -> String? {
        guard token.hasPrefix("\""), token.hasSuffix("\""), token.count >= 2 else {
            return nil
        }
        return String(token.dropFirst().dropLast())
    }

    private static func unescape(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }

    private static func escape(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
