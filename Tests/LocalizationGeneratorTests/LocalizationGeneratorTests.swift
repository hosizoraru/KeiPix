import Foundation
import Testing
@testable import LocalizationGenerator

@Suite("StringsFile parser")
struct StringsFileTests {
    @Test("Parses canonical key/value lines")
    func parsesCanonicalLines() {
        let source = """
        "Hello" = "你好";
        "Goodbye" = "再见";
        """
        let file = StringsFile.parse(contents: source)
        #expect(file.entries.count == 2)
        #expect(file.entries[0].key == "Hello")
        #expect(file.entries[0].value == "你好")
        #expect(file.entries[1].key == "Goodbye")
        #expect(file.entries[1].value == "再见")
    }

    @Test("Skips blank lines and comments")
    func skipsBlankAndCommentLines() {
        let source = """
        // header comment
        "Hello" = "你好";

        /* multi-line opener */
        "Goodbye" = "再见";
        """
        let file = StringsFile.parse(contents: source)
        #expect(file.keys == ["Hello", "Goodbye"])
    }

    @Test("Round-trips through render")
    func renderRoundTrip() {
        let original = StringsFile(entries: [
            ("Hello", "你好"),
            ("Path", #"C:\Users\test"#),
            ("Quote", #""quoted""#),
            ("Newline", "line1\nline2")
        ])
        let rendered = original.render()
        let parsed = StringsFile.parse(contents: rendered)
        #expect(parsed.entries.count == original.entries.count)
        for (parsedEntry, expectedEntry) in zip(parsed.entries, original.entries) {
            #expect(parsedEntry.key == expectedEntry.key)
            #expect(parsedEntry.value == expectedEntry.value)
        }
    }

    @Test("Render emits canonical line shape with optional header")
    func renderProducesCanonicalShape() {
        let file = StringsFile(entries: [("Hello", "你好")])
        let withHeader = file.render(header: "Auto generated\nDo not edit")
        #expect(withHeader.hasPrefix("// Auto generated\n// Do not edit\n\n"))
        #expect(withHeader.contains("\"Hello\" = \"你好\";\n"))
    }

    @Test("Lookup helper returns the value for a key")
    func valueLookup() {
        let file = StringsFile(entries: [
            ("First", "1"),
            ("Second", "2")
        ])
        #expect(file.value(for: "Second") == "2")
        #expect(file.value(for: "Missing") == nil)
    }
}

@Suite("Simplified to traditional conversion")
struct SimplifiedToTraditionalTests {
    @Test("Converts characters across the canonical map")
    func charactersConvert() {
        // Each input character has a deterministic mapping in the
        // canonical table; chars without entries (e.g. `作`, `品`)
        // pass through unchanged, which is the right behaviour.
        #expect(SimplifiedToTraditional.convert("发现") == "發現")
        #expect(SimplifiedToTraditional.convert("图书") == "圖書")
        // 登录 → 登入 (override) and 历史 → 紀錄 (Taiwan UI override).
        #expect(SimplifiedToTraditional.convert("登录历史") == "登入紀錄")
    }

    @Test("Word overrides win over single-character mapping")
    func wordOverrides() {
        // 默认 → 預設 (Taiwan), not 默認.
        #expect(SimplifiedToTraditional.convert("默认").contains("預設"))
        // 缓存 → 快取.
        #expect(SimplifiedToTraditional.convert("缓存大小") == "快取大小")
        // 文件 → 檔案 (Taiwan).
        #expect(SimplifiedToTraditional.convert("打开文件").hasSuffix("檔案"))
        // 登录 → 登入 wins before 录 → 錄 fires alone.
        #expect(SimplifiedToTraditional.convert("登录") == "登入")
    }

    @Test("Format specifiers and ASCII pass through unchanged")
    func passesThroughASCII() {
        let source = "已加载 %d 篇文章 · %@"
        let converted = SimplifiedToTraditional.convert(source)
        #expect(converted.contains("%d"))
        #expect(converted.contains("%@"))
        #expect(converted.contains("·"))
    }

    @Test("Handles empty strings")
    func emptyStringPassesThrough() {
        #expect(SimplifiedToTraditional.convert("") == "")
    }
}

@Suite("Japanese curated translations")
struct JapaneseTranslationsTests {
    @Test("Returns nil for keys not in the dictionary")
    func missingKey() {
        #expect(JapaneseTranslations.translation(for: "Definitely not in the table") == nil)
    }

    @Test("Looks up curated translations for common UI keys")
    func curatedHits() {
        #expect(JapaneseTranslations.translation(for: "Login") == "ログイン")
        #expect(JapaneseTranslations.translation(for: "Logout") == "ログアウト")
        #expect(JapaneseTranslations.translation(for: "Bookmarks") == "ブックマーク")
        #expect(JapaneseTranslations.translation(for: "Manga") == "マンガ")
        #expect(JapaneseTranslations.translation(for: "Settings") == "設定")
    }

    @Test("Pixiv-specific terms use native Japanese forms")
    func pixivTerms() {
        #expect(JapaneseTranslations.translation(for: "Ugoira") == "うごイラ")
        #expect(JapaneseTranslations.translation(for: "R-18") == "R-18")
        #expect(JapaneseTranslations.translation(for: "Trending Tags") == "急上昇タグ")
    }
}
