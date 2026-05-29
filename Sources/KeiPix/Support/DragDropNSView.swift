#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// NSView wrapper for drop target support with custom visual feedback.
///
/// Provides richer drop handling than SwiftUI's `.dropDestination`:
/// - Custom drop zone visual feedback
/// - Animated drop effects
/// - Multiple file type support
/// - Precise drop position control
struct DropTargetNSView: NSViewRepresentable {
    let acceptedTypes: [UTType]
    let onDrop: ([URL]) -> Bool
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
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {}
}

/// Custom NSView that implements NSDraggingDestination.
class DropTargetView: NSView {
    var onDrop: (([URL]) -> Bool)?
    var onDragEntered: (() -> Void)?
    var onDragExited: (() -> Void)?

    private var isHighlighted = false

    override var acceptsFirstResponder: Bool { true }

    // MARK: - NSDraggingDestination

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        guard onDrop != nil else { return [] }
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
        return onDrop != nil
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        guard let onDrop else { return false }

        let urls = sender.draggingPasteboard.pasteboardItems?.compactMap { item -> URL? in
            if let urlString = item.string(forType: .fileURL) {
                return URL(string: urlString)
            }
            if let urlString = item.string(forType: .URL) {
                return URL(string: urlString)
            }
            return nil
        } ?? []

        isHighlighted = false
        needsDisplay = true

        return onDrop(urls)
    }

    override func concludeDragOperation(_ sender: (any NSDraggingInfo)?) {
        isHighlighted = false
        needsDisplay = true
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
    let onDrop: ([URL]) -> Bool
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
