#if os(iOS)
import UIKit
import SwiftUI

/// UIGestureRecognizer bridge for iPadOS.
///
/// Provides UIKit gesture recognizers that SwiftUI's gesture
/// modifiers can't match:
/// - Continuous pan with velocity
/// - Pinch with anchor point
/// - Rotation gestures
/// - Multiple simultaneous gestures
struct GestureRecognizerBridge: UIViewRepresentable {
    let onPan: ((CGFloat, CGFloat, UIGestureRecognizer.State) -> Void)?
    let onPinch: ((CGFloat, UIGestureRecognizer.State) -> Void)?
    let onRotation: ((CGFloat, UIGestureRecognizer.State) -> Void)?
    let onDoubleTap: (() -> Void)?

    func makeUIView(context: Context) -> GestureView {
        let view = GestureView()
        view.onPan = onPan
        view.onPinch = onPinch
        view.onRotation = onRotation
        view.onDoubleTap = onDoubleTap
        return view
    }

    func updateUIView(_ uiView: GestureView, context: Context) {
        uiView.onPan = onPan
        uiView.onPinch = onPinch
        uiView.onRotation = onRotation
        uiView.onDoubleTap = onDoubleTap
    }
}

class GestureView: UIView {
    var onPan: ((CGFloat, CGFloat, UIGestureRecognizer.State) -> Void)?
    var onPinch: ((CGFloat, UIGestureRecognizer.State) -> Void)?
    var onRotation: ((CGFloat, UIGestureRecognizer.State) -> Void)?
    var onDoubleTap: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.delegate = self
        addGestureRecognizer(pan)

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        pinch.delegate = self
        addGestureRecognizer(pinch)

        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        rotation.delegate = self
        addGestureRecognizer(rotation)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self)
        onPan?(translation.x, translation.y, gesture.state)
    }

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        onPinch?(gesture.scale, gesture.state)
    }

    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        onRotation?(gesture.rotation, gesture.state)
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        onDoubleTap?()
    }
}

extension GestureView: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}

// MARK: - SwiftUI wrapper

/// SwiftUI view with UIKit gesture recognizers for iPadOS.
struct iPadGestureView<Content: View>: View {
    let onPan: ((CGFloat, CGFloat, UIGestureRecognizer.State) -> Void)?
    let onPinch: ((CGFloat, UIGestureRecognizer.State) -> Void)?
    let onRotation: ((CGFloat, UIGestureRecognizer.State) -> Void)?
    let onDoubleTap: (() -> Void)?
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .overlay {
                GestureRecognizerBridge(
                    onPan: onPan,
                    onPinch: onPinch,
                    onRotation: onRotation,
                    onDoubleTap: onDoubleTap
                )
            }
    }
}
#endif
