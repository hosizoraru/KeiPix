#if os(macOS)
import AppKit
import SwiftUI

/// NSSearchField wrapper with native IME support and autocomplete.
///
/// Replaces SwiftUI's `TextField` + `.searchable` with native
/// `NSSearchField` that provides:
/// - Full IME support (Japanese/Chinese input methods)
/// - Native search field styling
/// - History dropdown
/// - Better autocomplete integration
struct SearchFieldNSView: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let suggestions: [String]
    let onSubmit: () -> Void
    let onTextChange: (String) -> Void

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField()
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = true
        searchField.sendsWholeSearchString = false
        searchField.delegate = context.coordinator
        searchField.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        searchField.controlSize = .regular

        // Configure for IME support
        searchField.allowsEditingTextAttributes = false
        searchField.isAutomaticTextCompletionEnabled = true

        context.coordinator.searchField = searchField
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        // Only update if text changed externally
        if searchField.stringValue != text {
            searchField.stringValue = text
        }

        // Update suggestions
        context.coordinator.suggestions = suggestions
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onSubmit: onSubmit,
            onTextChange: onTextChange
        )
    }

    class Coordinator: NSObject, NSSearchFieldDelegate {
        @Binding var text: String
        let onSubmit: () -> Void
        let onTextChange: (String) -> Void
        var suggestions: [String] = []
        var searchField: NSSearchField?

        init(
            text: Binding<String>,
            onSubmit: @escaping () -> Void,
            onTextChange: @escaping (String) -> Void
        ) {
            self._text = text
            self.onSubmit = onSubmit
            self.onTextChange = onTextChange
        }

        // MARK: - NSSearchFieldDelegate

        func controlTextDidChange(_ obj: Notification) {
            guard let searchField = obj.object as? NSSearchField else { return }
            let newText = searchField.stringValue
            text = newText
            onTextChange(newText)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let searchField = obj.object as? NSSearchField else { return }
            let reason = obj.userInfo?["NSFieldEditor"] as? NSTextView
            if reason?.textStorage?.string.isEmpty == false {
                onSubmit()
            }
        }

        // MARK: - Menu for suggestions

        func searchFieldDidStartSearching(_ searchField: NSSearchField) {
            // Show suggestions menu if available
            guard suggestions.isEmpty == false else { return }
            let menu = NSMenu()
            for suggestion in suggestions.prefix(10) {
                let item = NSMenuItem(title: suggestion, action: #selector(selectSuggestion(_:)), keyEquivalent: "")
                item.target = self
                menu.addItem(item)
            }
            searchField.menu = menu
        }

        func searchFieldDidEndSearching(_ searchField: NSSearchField) {
            searchField.menu = nil
        }

        @objc private func selectSuggestion(_ sender: NSMenuItem) {
            text = sender.title
            searchField?.stringValue = sender.title
            onSubmit()
        }
    }
}

// MARK: - SwiftUI wrapper

/// SwiftUI view that uses NSSearchField for better IME support.
struct NativeSearchField: View {
    @Binding var text: String
    let placeholder: String
    let suggestions: [String]
    let onSubmit: () -> Void
    let onTextChange: (String) -> Void

    var body: some View {
        SearchFieldNSView(
            text: $text,
            placeholder: placeholder,
            suggestions: suggestions,
            onSubmit: onSubmit,
            onTextChange: onTextChange
        )
        .frame(height: 28)
    }
}
#endif
