#if os(macOS)
import AppKit
import SwiftUI

struct TrackpadScrollEvent {
    let deltaX: CGFloat
    let deltaY: CGFloat
    let phase: NSEvent.Phase
    let momentumPhase: NSEvent.Phase

    var isFinished: Bool {
        phase.contains(.ended) || phase.contains(.cancelled)
    }

    var isMomentum: Bool {
        momentumPhase.isEmpty == false
    }
}

struct TrackpadEventBridge: NSViewRepresentable {
    var isEnabled: Bool
    var onScroll: (TrackpadScrollEvent) -> Bool
    var onMagnify: (CGFloat, NSEvent.Phase) -> Bool
    var onSmartMagnify: () -> Bool
    var onDrag: (CGSize) -> Bool

    func makeNSView(context: Context) -> TrackpadEventView {
        let view = TrackpadEventView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: TrackpadEventView, context: Context) {
        nsView.isEnabled = isEnabled
        nsView.onScroll = onScroll
        nsView.onMagnify = onMagnify
        nsView.onSmartMagnify = onSmartMagnify
        nsView.onDrag = onDrag
    }
}

final class TrackpadEventView: NSView {
    var isEnabled = true
    var onScroll: (TrackpadScrollEvent) -> Bool = { _ in false }
    var onMagnify: (CGFloat, NSEvent.Phase) -> Bool = { _, _ in false }
    var onSmartMagnify: () -> Bool = { false }
    var onDrag: (CGSize) -> Bool = { _ in false }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard isEnabled else {
            super.scrollWheel(with: event)
            return
        }

        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
        let scrollEvent = TrackpadScrollEvent(
            deltaX: event.scrollingDeltaX * multiplier,
            deltaY: event.scrollingDeltaY * multiplier,
            phase: event.phase,
            momentumPhase: event.momentumPhase
        )

        if onScroll(scrollEvent) {
            return
        }
        super.scrollWheel(with: event)
    }

    override func magnify(with event: NSEvent) {
        guard isEnabled, onMagnify(event.magnification, event.phase) else {
            super.magnify(with: event)
            return
        }
    }

    override func smartMagnify(with event: NSEvent) {
        guard isEnabled, onSmartMagnify() else {
            super.smartMagnify(with: event)
            return
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, onDrag(CGSize(width: event.deltaX, height: event.deltaY)) else {
            super.mouseDragged(with: event)
            return
        }
    }
}
#endif
