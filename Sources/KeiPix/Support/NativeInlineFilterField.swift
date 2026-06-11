#if os(iOS)
import SwiftUI
import UIKit

struct NativeInlineFilterField: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let accessibilityLabel: String
    let usesTransparentBackground: Bool

    init(
        text: Binding<String>,
        placeholder: String,
        accessibilityLabel: String,
        usesTransparentBackground: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.accessibilityLabel = accessibilityLabel
        self.usesTransparentBackground = usesTransparentBackground
    }

    func makeUIView(context: Context) -> UISearchTextField {
        let field = UISearchTextField(frame: .zero)
        field.delegate = context.coordinator
        field.placeholder = placeholder
        field.text = text
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.returnKeyType = .done
        field.accessibilityLabel = accessibilityLabel
        applyBackground(to: field)
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
        applyBackground(to: field)
        if field.text != text {
            field.text = text
        }
    }

    private func applyBackground(to field: UISearchTextField) {
        if usesTransparentBackground {
            field.borderStyle = .none
            field.background = UIImage()
            field.disabledBackground = UIImage()
            field.backgroundColor = .clear
            field.clearButtonMode = .never
            field.layer.backgroundColor = UIColor.clear.cgColor
            field.layer.cornerRadius = 0
        } else {
            field.borderStyle = .none
            field.background = nil
            field.disabledBackground = nil
            field.backgroundColor = UIColor.secondarySystemFill
            field.clearButtonMode = .whileEditing
            field.layer.cornerRadius = 12
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

        func textFieldShouldClear(_ textField: UITextField) -> Bool {
            text.wrappedValue = ""
            return true
        }
    }
}
#endif
