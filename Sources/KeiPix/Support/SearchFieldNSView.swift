import SwiftUI
#if os(macOS)
import AppKit

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

    @MainActor
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
            guard obj.object is NSSearchField else { return }
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
#elseif os(iOS)
import UIKit

/// UISearchTextField wrapper for iPadOS creator/search surfaces.
///
/// This mirrors the macOS NSSearchField bridge so SwiftUI owns the
/// binding while UIKit owns the native text input, IME, and clear button.
struct SearchFieldUIView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let suggestions: [String]
    let onSubmit: () -> Void
    let onTextChange: (String) -> Void

    func makeUIView(context: Context) -> UISearchTextField {
        let searchField = UISearchTextField()
        searchField.placeholder = placeholder
        searchField.borderStyle = .roundedRect
        searchField.returnKeyType = .search
        searchField.clearButtonMode = .whileEditing
        searchField.autocorrectionType = .no
        searchField.autocapitalizationType = .none
        searchField.delegate = context.coordinator
        searchField.addTarget(
            context.coordinator,
            action: #selector(Coordinator.textDidChange(_:)),
            for: .editingChanged
        )
        context.coordinator.searchField = searchField
        return searchField
    }

    func updateUIView(_ searchField: UISearchTextField, context: Context) {
        if searchField.text != text {
            searchField.text = text
        }
        context.coordinator.suggestions = suggestions
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onSubmit: onSubmit,
            onTextChange: onTextChange
        )
    }

    @MainActor
    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var text: String
        let onSubmit: () -> Void
        let onTextChange: (String) -> Void
        var suggestions: [String] = []
        weak var searchField: UISearchTextField?

        init(
            text: Binding<String>,
            onSubmit: @escaping () -> Void,
            onTextChange: @escaping (String) -> Void
        ) {
            self._text = text
            self.onSubmit = onSubmit
            self.onTextChange = onTextChange
        }

        @objc func textDidChange(_ sender: UISearchTextField) {
            let newText = sender.text ?? ""
            text = newText
            onTextChange(newText)
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            onSubmit()
            textField.resignFirstResponder()
            return true
        }
    }
}
#endif

// MARK: - SwiftUI wrapper

/// SwiftUI view that uses NSSearchField for better IME support.
struct NativeSearchField: View {
    @Binding var text: String
    let placeholder: String
    let suggestions: [String]
    let onSubmit: () -> Void
    let onTextChange: (String) -> Void

    var body: some View {
        #if os(macOS)
        SearchFieldNSView(
            text: $text,
            placeholder: placeholder,
            suggestions: suggestions,
            onSubmit: onSubmit,
            onTextChange: onTextChange
        )
        .frame(height: 28)
        #elseif os(iOS)
        SearchFieldUIView(
            text: $text,
            placeholder: placeholder,
            suggestions: suggestions,
            onSubmit: onSubmit,
            onTextChange: onTextChange
        )
        .frame(height: 34)
        #endif
    }
}
