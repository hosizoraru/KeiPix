import SwiftUI

/// Cross-platform gesture event for reader navigation.
///
/// Replaces the macOS-specific `TrackpadScrollEvent` with a
/// platform-agnostic type that works on both macOS and iPadOS.
struct ReaderScrollEvent {
    let deltaX: CGFloat
    let deltaY: CGFloat
    var velocityX: CGFloat? = nil
    var velocityY: CGFloat? = nil
    let isFinished: Bool
    let isMomentum: Bool
}

/// Cross-platform gesture bridge for reader views.
///
/// On macOS: wraps `TrackpadEventBridge` (NSViewRepresentable)
/// On iPadOS: uses SwiftUI gesture recognizers
struct ReaderGestureBridge: ViewModifier {
    let isEnabled: Bool
    let onScroll: (ReaderScrollEvent) -> Bool
    let onMagnify: (CGFloat, Bool) -> Bool
    let onSmartMagnify: () -> Bool
    let onDrag: (CGSize) -> Bool
    @State private var lastDragTranslation: CGSize = .zero

    func body(content: Content) -> some View {
        content
            .overlay {
                #if os(macOS)
                macOSGestureBridge
                #else
                iOSGestureBridge
                #endif
            }
    }

    #if os(macOS)
    private var macOSGestureBridge: some View {
        TrackpadEventBridge(
            isEnabled: isEnabled,
            onScroll: { event in
                let readerEvent = ReaderScrollEvent(
                    deltaX: event.deltaX,
                    deltaY: event.deltaY,
                    velocityX: nil,
                    velocityY: nil,
                    isFinished: event.isFinished,
                    isMomentum: event.isMomentum
                )
                return onScroll(readerEvent)
            },
            onMagnify: { delta, phase in
                let isEnded = phase.contains(.ended) || phase.contains(.cancelled)
                return onMagnify(delta, isEnded)
            },
            onSmartMagnify: onSmartMagnify,
            onDrag: onDrag
        )
    }
    #endif

    #if os(iOS)
    private var iOSGestureBridge: some View {
        GeometryReader { _ in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            guard isEnabled else { return }
                            let deltaX = value.translation.width - lastDragTranslation.width
                            let deltaY = value.translation.height - lastDragTranslation.height
                            lastDragTranslation = value.translation
                            let velocity = Self.projectedVelocity(from: value)
                            let event = ReaderScrollEvent(
                                deltaX: deltaX,
                                deltaY: deltaY,
                                velocityX: velocity.width,
                                velocityY: velocity.height,
                                isFinished: false,
                                isMomentum: false
                            )
                            _ = onScroll(event)
                        }
                        .onEnded { value in
                            guard isEnabled else { return }
                            let deltaX = value.translation.width - lastDragTranslation.width
                            let deltaY = value.translation.height - lastDragTranslation.height
                            lastDragTranslation = .zero
                            let velocity = Self.projectedVelocity(from: value)
                            let event = ReaderScrollEvent(
                                deltaX: deltaX,
                                deltaY: deltaY,
                                velocityX: velocity.width,
                                velocityY: velocity.height,
                                isFinished: true,
                                isMomentum: false
                            )
                            _ = onScroll(event)
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { scale in
                            guard isEnabled else { return }
                            _ = onMagnify(scale - 1, false)
                        }
                        .onEnded { scale in
                            guard isEnabled else { return }
                            _ = onMagnify(scale - 1, true)
                        }
                )
                .onTapGesture(count: 2) {
                    guard isEnabled else { return }
                    _ = onSmartMagnify()
                }
        }
    }

    private static func projectedVelocity(from value: DragGesture.Value) -> CGSize {
        let projectionWindow: CGFloat = 0.16
        return CGSize(
            width: (value.predictedEndTranslation.width - value.translation.width) / projectionWindow,
            height: (value.predictedEndTranslation.height - value.translation.height) / projectionWindow
        )
    }
    #endif
}

extension View {
    /// Apply cross-platform reader gestures.
    func readerGestures(
        isEnabled: Bool = true,
        onScroll: @escaping (ReaderScrollEvent) -> Bool,
        onMagnify: @escaping (CGFloat, Bool) -> Bool,
        onSmartMagnify: @escaping () -> Bool,
        onDrag: @escaping (CGSize) -> Bool
    ) -> some View {
        modifier(ReaderGestureBridge(
            isEnabled: isEnabled,
            onScroll: onScroll,
            onMagnify: onMagnify,
            onSmartMagnify: onSmartMagnify,
            onDrag: onDrag
        ))
    }
}
