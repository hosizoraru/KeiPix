import SwiftUI

/// Single source of truth for every keyboard shortcut declared in KeiPix's
/// command menus and reader surfaces.
///
/// Each menu/reader site reads its key-binding from the catalog instead of
/// hard-coding `keyboardShortcut(_:modifiers:)` strings inline. The Keyboard
/// settings page reflects the same catalog so the UI never drifts from the
/// shortcuts that actually fire.
///
/// macOS lets users override any menu-item shortcut through System Settings →
/// Keyboard → Keyboard Shortcuts → App Shortcuts (matched on menu-item title),
/// so the catalog records the *factory defaults* and the settings page
/// deep-links into that pane. Reader inline keys (`←`/`→`/`Space`/`Esc`)
/// don't surface in any menu, so they're listed as informational and marked
/// `isCustomizable == false`.
enum KeyboardShortcutCatalog {
    static let entries: [ShortcutCatalogEntry] = [
        // MARK: Main app commands
        ShortcutCatalogEntry(
            action: .refreshFeed,
            label: L10n.refresh,
            binding: ShortcutBinding(key: .character("r"), modifiers: [.command]),
            surface: .main,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .togglePrivacyMode,
            label: L10n.shortcutTogglePrivacyMode,
            binding: ShortcutBinding(key: .character("p"), modifiers: [.command, .shift]),
            surface: .main,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .openPixivLinkFromClipboard,
            label: L10n.openPixivLinkFromClipboard,
            binding: ShortcutBinding(key: .character("l"), modifiers: [.command, .shift]),
            surface: .main,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .searchLocalImageSource,
            label: L10n.searchLocalImageSource,
            binding: ShortcutBinding(key: .character("i"), modifiers: [.command, .option]),
            surface: .main,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .copyDiagnostics,
            label: L10n.copyDiagnostics,
            binding: ShortcutBinding(key: .character("g"), modifiers: [.command, .option]),
            surface: .main,
            isCustomizable: true
        ),

        // MARK: Artwork menu
        ShortcutCatalogEntry(
            action: .previousArtwork,
            label: L10n.previousArtwork,
            binding: ShortcutBinding(key: .leftArrow, modifiers: [.command]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .nextArtwork,
            label: L10n.nextArtwork,
            binding: ShortcutBinding(key: .rightArrow, modifiers: [.command]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .toggleBookmark,
            label: L10n.bookmark,
            binding: ShortcutBinding(key: .character("b"), modifiers: [.command]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .downloadArtwork,
            label: L10n.download,
            binding: ShortcutBinding(key: .character("d"), modifiers: [.command, .shift]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .searchImageSource,
            label: L10n.searchImageSource,
            binding: ShortcutBinding(key: .character("s"), modifiers: [.command, .option]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .openCreatorProfile,
            label: L10n.openCreatorProfile,
            binding: ShortcutBinding(key: .character("u"), modifiers: [.command]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .creatorIllustrations,
            label: L10n.creatorIllustrations,
            binding: ShortcutBinding(key: .character("u"), modifiers: [.command, .option]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .creatorManga,
            label: L10n.creatorManga,
            binding: ShortcutBinding(key: .character("u"), modifiers: [.command, .control]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .openReaderWindow,
            label: L10n.openReaderWindow,
            binding: ShortcutBinding(key: .returnKey, modifiers: [.command]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .openInPixiv,
            label: L10n.openInPixiv,
            binding: ShortcutBinding(key: .character("o"), modifiers: [.command, .shift]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .copyArtworkLink,
            label: L10n.copyLink,
            binding: ShortcutBinding(key: .character("c"), modifiers: [.command, .shift]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .selectAll,
            label: L10n.selectAll,
            binding: ShortcutBinding(key: .character("a"), modifiers: [.command]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .clearSelection,
            label: L10n.clearSelection,
            binding: ShortcutBinding(key: .character("a"), modifiers: [.command, .shift]),
            surface: .artwork,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .copySelectedLinks,
            label: L10n.copySelectedArtworkLinks,
            binding: ShortcutBinding(key: .character("c"), modifiers: [.command, .option]),
            surface: .artwork,
            isCustomizable: true
        ),

        // MARK: Downloads menu
        ShortcutCatalogEntry(
            action: .openDownloads,
            label: L10n.openDownloads,
            binding: ShortcutBinding(key: .character("d"), modifiers: [.command, .option]),
            surface: .downloads,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .batchDownloadLoadedArtworks,
            label: L10n.batchDownloadLoadedArtworks,
            binding: ShortcutBinding(key: .character("d"), modifiers: [.command, .control]),
            surface: .downloads,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .togglePauseDownloads,
            label: L10n.shortcutTogglePauseDownloads,
            binding: ShortcutBinding(key: .character("p"), modifiers: [.command, .option]),
            surface: .downloads,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .openDownloadFolder,
            label: L10n.openFolder,
            binding: ShortcutBinding(key: .character("f"), modifiers: [.command, .option]),
            surface: .downloads,
            isCustomizable: true
        ),

        // MARK: Reader window
        ShortcutCatalogEntry(
            action: .readerJumpToPage,
            label: L10n.readerJumpToPage,
            binding: ShortcutBinding(key: .character("j"), modifiers: [.command]),
            surface: .readerWindow,
            isCustomizable: true
        ),
        ShortcutCatalogEntry(
            action: .readerToggleFullscreen,
            label: L10n.readerToggleFullscreen,
            binding: ShortcutBinding(key: .character("f"), modifiers: [.command, .shift]),
            surface: .readerWindow,
            isCustomizable: true
        ),

        // MARK: Reader inline (not customizable — bound to hidden buttons,
        // so System Settings → App Shortcuts has nothing to override).
        ShortcutCatalogEntry(
            action: .readerPreviousPage,
            label: L10n.previousPage,
            binding: ShortcutBinding(key: .leftArrow, modifiers: []),
            surface: .readerInline,
            isCustomizable: false
        ),
        ShortcutCatalogEntry(
            action: .readerNextPage,
            label: L10n.nextPage,
            binding: ShortcutBinding(key: .rightArrow, modifiers: []),
            surface: .readerInline,
            isCustomizable: false
        ),
        ShortcutCatalogEntry(
            action: .readerResetZoom,
            label: L10n.resetZoom,
            binding: ShortcutBinding(key: .escape, modifiers: []),
            surface: .readerInline,
            isCustomizable: false
        ),
        ShortcutCatalogEntry(
            action: .readerToggleZoom,
            label: L10n.toggleZoom,
            binding: ShortcutBinding(key: .space, modifiers: []),
            surface: .readerInline,
            isCustomizable: false
        )
    ]

    /// Action → entry lookup. Trapping subscript keeps the API ergonomic;
    /// the dedicated test suite asserts every `ShortcutAction` is covered
    /// so a missing case can't reach release.
    private static let entriesByAction: [ShortcutAction: ShortcutCatalogEntry] = {
        Dictionary(uniqueKeysWithValues: entries.map { ($0.action, $0) })
    }()

    static func entry(for action: ShortcutAction) -> ShortcutCatalogEntry {
        guard let match = entriesByAction[action] else {
            preconditionFailure("KeyboardShortcutCatalog missing entry for \(action)")
        }
        return match
    }

    static func binding(for action: ShortcutAction) -> ShortcutBinding {
        entry(for: action).binding
    }

    static func entries(in surface: ShortcutSurface) -> [ShortcutCatalogEntry] {
        entries.filter { $0.surface == surface }
    }
}

// MARK: - Action identifiers

/// Stable identifiers for every catalog entry. Ordering reflects the
/// surface grouping so iteration matches the on-screen layout.
enum ShortcutAction: String, CaseIterable, Sendable {
    case refreshFeed
    case togglePrivacyMode
    case openPixivLinkFromClipboard
    case searchLocalImageSource
    case copyDiagnostics

    case previousArtwork
    case nextArtwork
    case toggleBookmark
    case downloadArtwork
    case searchImageSource
    case openCreatorProfile
    case creatorIllustrations
    case creatorManga
    case openReaderWindow
    case openInPixiv
    case copyArtworkLink
    case selectAll
    case clearSelection
    case copySelectedLinks

    case openDownloads
    case batchDownloadLoadedArtworks
    case togglePauseDownloads
    case openDownloadFolder

    case readerJumpToPage
    case readerToggleFullscreen

    case readerPreviousPage
    case readerNextPage
    case readerResetZoom
    case readerToggleZoom
}

// MARK: - Catalog entry

struct ShortcutCatalogEntry: Identifiable, Sendable {
    let action: ShortcutAction
    let label: String
    let binding: ShortcutBinding
    let surface: ShortcutSurface
    let isCustomizable: Bool

    var id: ShortcutAction { action }
}

// MARK: - Surfaces

/// Logical groupings rendered as separate sections on the Keyboard settings
/// page. Order matches the menu-bar layout users already see.
enum ShortcutSurface: String, CaseIterable, Identifiable, Sendable {
    case main
    case artwork
    case downloads
    case readerWindow
    case readerInline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .main: return L10n.shortcutSurfaceMain
        case .artwork: return L10n.artwork
        case .downloads: return L10n.downloads
        case .readerWindow: return L10n.readerWindow
        case .readerInline: return L10n.shortcutSurfaceReaderInline
        }
    }
}

// MARK: - Shortcut binding

/// Pair of a printable key plus modifier mask, paired with the SF-style
/// glyph string the settings page renders.
///
/// Wraps SwiftUI's `KeyEquivalent` instead of using it directly so the
/// catalog can hold special keys (arrows, escape, return, space) alongside
/// plain characters with one stable display rule.
struct ShortcutBinding: Sendable, Equatable {
    enum Key: Sendable, Equatable {
        case character(Character)
        case leftArrow
        case rightArrow
        case upArrow
        case downArrow
        case escape
        case space
        case returnKey

        var keyEquivalent: KeyEquivalent {
            switch self {
            case .character(let value): return KeyEquivalent(value)
            case .leftArrow: return .leftArrow
            case .rightArrow: return .rightArrow
            case .upArrow: return .upArrow
            case .downArrow: return .downArrow
            case .escape: return .escape
            case .space: return .space
            case .returnKey: return .return
            }
        }

        var displayGlyph: String {
            switch self {
            case .character(let value): return String(value).uppercased()
            case .leftArrow: return "\u{2190}"
            case .rightArrow: return "\u{2192}"
            case .upArrow: return "\u{2191}"
            case .downArrow: return "\u{2193}"
            case .escape: return "\u{238B}"
            case .space: return "\u{2423}"
            case .returnKey: return "\u{21A9}"
            }
        }
    }

    let key: Key
    let modifiers: EventModifiers

    /// Glyph string in macOS Apple-menu order (control, option, shift,
    /// command, then key) so users see the same shape Apple's own menu bar
    /// renders for the same shortcut.
    var displayString: String {
        var output = ""
        if modifiers.contains(.control) { output.append("\u{2303}") }
        if modifiers.contains(.option) { output.append("\u{2325}") }
        if modifiers.contains(.shift) { output.append("\u{21E7}") }
        if modifiers.contains(.command) { output.append("\u{2318}") }
        output.append(key.displayGlyph)
        return output
    }
}

// MARK: - View ergonomics

extension View {
    /// Apply a catalog binding directly: `.shortcut(.refreshFeed)`.
    func shortcut(_ action: ShortcutAction) -> some View {
        let binding = KeyboardShortcutCatalog.binding(for: action)
        return keyboardShortcut(binding.key.keyEquivalent, modifiers: binding.modifiers)
    }
}
