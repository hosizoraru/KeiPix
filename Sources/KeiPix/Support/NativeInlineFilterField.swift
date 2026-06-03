#if os(iOS)
import SwiftUI
import UIKit

struct NativeInlineFilterField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let accessibilityLabel: String

    init(
        text: Binding<String>,
        placeholder: String,
        accessibilityLabel: String
    ) {
        self._text = text
        self.placeholder = placeholder
        self.accessibilityLabel = accessibilityLabel
    }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField(frame: .zero)
        field.delegate = context.coordinator
        field.placeholder = placeholder
        field.text = text
        field.clearButtonMode = .whileEditing
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        field.accessibilityLabel = accessibilityLabel
        field.backgroundColor = UIColor.secondarySystemFill
        field.layer.cornerRadius = 12
        field.clipsToBounds = true
        field.addTarget(
            context.coordinator,
            action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged
        )
        return field
    }

    func updateUIView(_ field: UISearchTextField, context: Context) {
        context.coordinator.text = $text
        field.placeholder = placeholder
        field.accessibilityLabel = accessibilityLabel
        if field.text != text {
            field.text = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    @MainActor
    final class Coordinator: NSObject, UITextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        @objc func editingChanged(_ sender: UISearchTextField) {
            text.wrappedValue = sender.text ?? ""
        }

        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
#endif
