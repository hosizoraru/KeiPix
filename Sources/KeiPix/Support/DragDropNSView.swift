#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct NativeDropPayload: Equatable {
    let rawText: String
    let url: URL?
    let typeIdentifier: String
}

/// NSView wrapper for drop target support with custom visual feedback.
///
/// Provides richer drop handling than SwiftUI's `.dropDestination`:
/// - Custom drop zone visual feedback
/// - Animated drop effects
/// - Multiple file type support
/// - Precise drop position control
struct DropTargetNSView: NSViewRepresentable {
    let acceptedTypes: [UTType]
    let onDrop: ([NativeDropPayload]) -> Bool
    let onDragEntered: (() -> Void)?
    let onDragExited: (() -> Void)?

    func makeNSView(context: Context) -> DropTargetView {
        let view = DropTargetView()
        view.onDrop = onDrop
        view.onDragEntered = onDragEntered
        view.onDragExited = onDragExited
        view.registerForDraggedTypes(acceptedTypes.map { .init($0.identifier) })
        return view
    }

    func updateNSView(_ nsView: DropTargetView, context: Context) {
        nsView.onDrop = onDrop
        nsView.onDragEntered = onDragEntered
        nsView.onDragExited = onDragExited
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {}
}

/// Custom NSView that implements NSDraggingDestination.
class DropTargetView: NSView {
    var onDrop: (([NativeDropPayload]) -> Bool)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?

    private var isHighlighted = false

    override var acceptsFirstResponder: Bool { true }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard onDrop != nil, readablePayloads(from: sender.draggingPasteboard).isEmpty == false else { return [] }
        isHighlighted = true
        needsDisplay = true
        onDragEntered?()
        return .copy
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        isHighlighted = false
        needsDisplay = true
        onDragExited?()
    }

    override func prepareForDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        onDrop != nil && readablePayloads(from: sender.draggingPasteboard).isEmpty == false
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let onDrop else { return false }

        let payloads = readablePayloads(from: sender.draggingPasteboard)
        guard payloads.isEmpty == false else { return false }

        isHighlighted = false
        needsDisplay = true

        return onDrop(payloads)
    }

    override func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        isHighlighted = false
        needsDisplay = true
    }

    private func readablePayloads(from pasteboard: NSPasteboard) -> [NativeDropPayload] {
        var payloads: [NativeDropPayload] = []

        for item in pasteboard.pasteboardItems ?? [] {
            appendPayload(
                rawText: item.string(forType: .URL),
                typeIdentifier: NSPasteboard.PasteboardType.URL.rawValue,
                to: &payloads
            )
            appendPayload(
                rawText: item.string(forType: .fileURL),
                typeIdentifier: NSPasteboard.PasteboardType.fileURL.rawValue,
                to: &payloads
            )
            appendPayload(
                rawText: item.string(forType: .string),
                typeIdentifier: NSPasteboard.PasteboardType.string.rawValue,
                to: &payloads
            )
            appendPayload(
                rawText: item.string(forType: NSPasteboard.PasteboardType(UTType.plainText.identifier)),
                typeIdentifier: UTType.plainText.identifier,
                to: &payloads
            )
            appendPayload(
                rawText: item.string(forType: NSPasteboard.PasteboardType(UTType.utf8PlainText.identifier)),
                typeIdentifier: UTType.utf8PlainText.identifier,
                to: &payloads
            )
        }

        return payloads
    }

    private func appendPayload(
        rawText: String?,
        typeIdentifier: String,
        to payloads: inout [NativeDropPayload]
    ) {
        guard let rawText, rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return
        }

        let url = URL(string: rawText)
        let payload = NativeDropPayload(rawText: rawText, url: url, typeIdentifier: typeIdentifier)
        guard payloads.contains(payload) == false else { return }
        payloads.append(payload)
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        if isHighlighted {
            let path = NSBezierPath(roundedRect: bounds, xRadius: 8, yRadius: 8)
            NSColor.selectedControlColor.withAlphaComponent(0.1).setFill()
            path.fill()

            NSColor.selectedControlColor.withAlphaComponent(0.3).setStroke()
            path.lineWidth = 2
            let dashPattern: [CGFloat] = [6, 3]
            path.setLineDash(dashPattern, count: dashPattern.count, phase: 0)
            path.stroke()
        }
    }
}

// MARK: - SwiftUI wrapper

/// SwiftUI view with custom drop target support.
struct CustomDropTarget<Content: View>: View {
    let acceptedTypes: [UTType]
    let onDrop: ([NativeDropPayload]) -> Bool
    let onDragEntered: (() -> Void)?
    let onDragExited: (() -> Void)?
    @ViewBuilder let content: () -> Content

    @State private var isDropTargeted = false

    var body: some View {
        content()
            .overlay {
                DropTargetNSView(
                    acceptedTypes: acceptedTypes,
                    onDrop: onDrop,
                    onDragEntered: {
                        isDropTargeted = true
                        onDragEntered?()
                    },
                    onDragExited: {
                        isDropTargeted = false
                        onDragExited?()
                    }
                )
            }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.5), lineWidth: 2)
                        .background(Color.accentColor.opacity(0.05))
                        .allowsHitTesting(false)
                }
            }
    }
}
#endif
