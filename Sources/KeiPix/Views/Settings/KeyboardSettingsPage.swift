import SwiftUI

/// Settings → Keyboard page.
///
/// Lists every shortcut declared in `KeyboardShortcutCatalog` grouped by
/// surface, plus an "Open Keyboard Shortcut Settings…" button that
/// deep-links into System Settings → Keyboard → Keyboard Shortcuts → App
/// Shortcuts. macOS treats this pane as the source of truth for menu-item
/// rebinding (matched on menu-item title), so KeiPix doesn't need to ship
/// its own recorder UI to honour user-customized bindings.
struct KeyboardSettingsPage: View {
    var body: some View {
        Form {
            Section {
                Button {
                    openKeyboardSystemSettings()
                } label: {
                    Label(L10n.openKeyboardSystemSettings, systemImage: "keyboard.badge.eye")
                }
                .os26GlassButton(prominent: true)
            } header: {
                Text(L10n.keyboardCustomization)
            } footer: {
                Text(L10n.keyboardCustomizationHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(ShortcutSurface.allCases) { surface in
                let entries = KeyboardShortcutCatalog.entries(in: surface)
                if entries.isEmpty == false {
                    Section {
                        ForEach(entries) { entry in
                            ShortcutCatalogRow(entry: entry)
                        }
                    } header: {
                        Text(surface.title)
                    } footer: {
                        if surface == .readerInline {
                            Text(L10n.keyboardReaderInlineHint)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.settingsKeyboard)
    }

    /// Deep-links into System Settings → Keyboard → Keyboard Shortcuts.
    /// The `x-apple.systempreferences:` URL scheme on macOS 13+ accepts a
    /// pane bundle ID plus an optional anchor; `KeyboardShortcuts` lands on
    /// the same tab the App Shortcuts list lives under. Falls back to
    /// opening the Keyboard pane root when the anchored variant fails so
    /// the button never silently no-ops.
    private func openKeyboardSystemSettings() {
        let anchored = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension?KeyboardShortcuts")
        if let anchored, PlatformWorkspace.open(anchored) {
            return
        }
        if let fallback = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            PlatformWorkspace.open(fallback)
        }
    }
}

/// Single catalog-row layout: localized action label on the left, glyph
/// pill on the right. Mirrors the macOS Keyboard Shortcuts list so users
/// can match rows by eye when they jump into System Settings.
private struct ShortcutCatalogRow: View {
    let entry: ShortcutCatalogEntry

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(entry.label)
                .font(.body)
            Spacer(minLength: 16)
            Text(entry.binding.displayString)
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .os26SkeletonSurface(8)
                .accessibilityLabel(accessibilityShortcutLabel)
        }
        .accessibilityElement(children: .combine)
    }

    /// Read out modifiers in spoken English ("Command Shift R") so VoiceOver
    /// users hear the same combo a sighted user reads off the glyph pill.
    private var accessibilityShortcutLabel: String {
        var parts: [String] = []
        let mods = entry.binding.modifiers
        if mods.contains(.control) { parts.append("Control") }
        if mods.contains(.option) { parts.append("Option") }
        if mods.contains(.shift) { parts.append("Shift") }
        if mods.contains(.command) { parts.append("Command") }
        parts.append(spokenKeyName(for: entry.binding.key))
        return parts.joined(separator: " ")
    }

    private func spokenKeyName(for key: ShortcutBinding.Key) -> String {
        switch key {
        case .character(let value): return String(value).uppercased()
        case .leftArrow: return L10n.keyLeftArrow
        case .rightArrow: return L10n.keyRightArrow
        case .upArrow: return L10n.keyUpArrow
        case .downArrow: return L10n.keyDownArrow
        case .escape: return L10n.keyEscape
        case .space: return L10n.keySpace
        case .returnKey: return L10n.keyReturn
        }
    }
}
