#if os(iOS)
import UIKit
import SwiftUI

/// UITextView wrapper for iPadOS novel reader.
///
/// Provides rich text rendering with:
/// - Native IME support (Japanese/Chinese)
/// - Text selection and copying
/// - Link handling
/// - Dynamic Type support
struct NovelTextUIView: UIViewRepresentable {
    let text: String
    let font: UIFont
    let textColor: UIColor
    let isEditable: Bool

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.font = font
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
        textView.font = font
        textView.textColor = textColor
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UITextViewDelegate {
        func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange, interaction: UITextItemInteraction) -> Bool {
            return true
        }
    }
}

/// SwiftUI wrapper for UITextView.
struct iPadNovelTextView: View {
    let text: String
    let fontSize: Double
    let fontFamily: NovelReaderFontFamily
    let theme: NovelReaderTheme

    var body: some View {
        NovelTextUIView(
            text: text,
            font: nsFont,
            textColor: UIColor(theme.foregroundColor),
            isEditable: false
        )
        .background(UIColor(theme.backgroundColor))
    }

    private var nsFont: UIFont {
        switch fontFamily {
        case .system:
            return UIFont.systemFont(ofSize: fontSize)
        case .serif:
            return UIFont(descriptor: UIFontDescriptor(name: "Georgia", size: fontSize), size: fontSize)
        case .monospaced:
            return UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        }
    }
}

// MARK: - UIDocumentPickerViewController

/// Document picker wrapper for iPadOS.
struct DocumentPickerView: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: ([URL]) -> Void

        init(onPick: @escaping ([URL]) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onPick(urls)
        }
    }
}

// MARK: - UIActivityViewController

/// Share sheet wrapper for iPadOS.
struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    let activities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: activities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - SwiftUI wrappers

/// SwiftUI view for document picking on iPadOS.
struct iPadDocumentPicker: View {
    let allowedTypes: [UTType]
    let onPick: ([URL]) -> Void
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(L10n.importToken, systemImage: "doc.badge.plus")
        }
        .sheet(isPresented: $isPresented) {
            DocumentPickerView(allowedTypes: allowedTypes, onPick: onPick)
        }
    }
}

/// SwiftUI view for sharing on iPadOS.
struct iPadShareSheet: View {
    let items: [Any]
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Label(L10n.share, systemImage: "square.and.arrow.up")
        }
        .sheet(isPresented: $isPresented) {
            ShareSheetView(items: items, activities: nil)
        }
    }
}
#endif
