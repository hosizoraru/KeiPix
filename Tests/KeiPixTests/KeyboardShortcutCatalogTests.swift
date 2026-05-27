import SwiftUI
import Testing
@testable import KeiPix

@Suite("Keyboard shortcut catalog")
struct KeyboardShortcutCatalogTests {

    @Test("Every ShortcutAction case has a catalog entry")
    func everyActionCovered() {
        for action in ShortcutAction.allCases {
            let match = KeyboardShortcutCatalog.entries.first { $0.action == action }
            #expect(match != nil, "Catalog missing entry for \(action)")
        }
    }

    @Test("Catalog entries have unique action identifiers")
    func entryIdentifiersUnique() {
        let identifiers = KeyboardShortcutCatalog.entries.map(\.action.rawValue)
        let uniqueCount = Set(identifiers).count
        #expect(uniqueCount == identifiers.count)
    }

    @Test("Customizable entries land on menu surfaces; reader inline stays read-only")
    func customizationFlagsAlignWithSurface() {
        for entry in KeyboardShortcutCatalog.entries {
            switch entry.surface {
            case .main, .artwork, .downloads, .readerWindow:
                #expect(entry.isCustomizable, "\(entry.action) should be customizable on \(entry.surface)")
            case .readerInline:
                #expect(entry.isCustomizable == false, "\(entry.action) inline reader keys must stay informational")
            }
        }
    }

    @Test("Display string composes Apple-order glyphs (control / option / shift / command + key)")
    func displayStringFollowsAppleOrder() {
        let binding = ShortcutBinding(
            key: .character("c"),
            modifiers: [.command, .shift, .option, .control]
        )
        #expect(binding.displayString == "\u{2303}\u{2325}\u{21E7}\u{2318}C")
    }

    @Test("Special-key glyphs render as their canonical macOS symbols")
    func specialKeyGlyphs() {
        let cases: [(ShortcutBinding.Key, String)] = [
            (.leftArrow, "\u{2190}"),
            (.rightArrow, "\u{2192}"),
            (.upArrow, "\u{2191}"),
            (.downArrow, "\u{2193}"),
            (.escape, "\u{238B}"),
            (.space, "\u{2423}"),
            (.returnKey, "\u{21A9}")
        ]
        for (key, glyph) in cases {
            let binding = ShortcutBinding(key: key, modifiers: [])
            #expect(binding.displayString == glyph)
        }
    }

    @Test("Character keys render uppercase regardless of stored case")
    func characterKeyUppercase() {
        let lower = ShortcutBinding(key: .character("r"), modifiers: [.command]).displayString
        let upper = ShortcutBinding(key: .character("R"), modifiers: [.command]).displayString
        #expect(lower == upper)
        #expect(lower == "\u{2318}R")
    }

    @Test("entries(in:) returns the surface in declaration order")
    func entriesPerSurface() {
        let main = KeyboardShortcutCatalog.entries(in: .main).map(\.action)
        #expect(main == [
            .refreshFeed,
            .togglePrivacyMode,
            .openPixivLinkFromClipboard,
            .searchLocalImageSource,
            .copyDiagnostics
        ])

        let readerInline = KeyboardShortcutCatalog.entries(in: .readerInline).map(\.action)
        #expect(readerInline == [
            .readerPreviousPage,
            .readerNextPage,
            .readerResetZoom,
            .readerToggleZoom
        ])
    }

    @Test("Catalog action lookup returns the registered binding")
    func catalogLookup() {
        let refresh = KeyboardShortcutCatalog.binding(for: .refreshFeed)
        #expect(refresh.modifiers == [.command])
        if case .character(let value) = refresh.key {
            #expect(value == "r")
        } else {
            Issue.record("refreshFeed binding lost its character key")
        }

        let prevArtwork = KeyboardShortcutCatalog.binding(for: .previousArtwork)
        #expect(prevArtwork.modifiers == [.command])
        if case .leftArrow = prevArtwork.key {
            // expected
        } else {
            Issue.record("previousArtwork should bind to the left arrow")
        }
    }

    @Test("System Settings deep link parses as a valid URL")
    func systemSettingsDeepLinkParses() {
        let anchored = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?KeyboardShortcuts")
        let fallback = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
        #expect(anchored != nil)
        #expect(fallback != nil)
    }
}
