#if os(iOS)
import UIKit
import SwiftUI

/// UIScrollView-based image viewer for iPadOS.
///
/// Provides smooth zoom/pan with:
/// - Native inertia scrolling
/// - Pinch-to-zoom with center point
/// - Double-tap to toggle zoom
/// - Bounce at edges
struct ImageScrollView: UIViewRepresentable {
    let imageURL: URL?
    let localURL: URL?
    let onZoomChanged: ((CGFloat) -> Void)?

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        scrollView.addSubview(imageView)
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 4.0
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bouncesZoom = true

        // Double-tap to zoom
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.loadImage(imageURL: imageURL, localURL: localURL)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.loadImage(imageURL: imageURL, localURL: localURL)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onZoomChanged: onZoomChanged)
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var scrollView: UIScrollView?
        var imageView: UIImageView?
        let onZoomChanged: ((CGFloat) -> Void)?

        init(onZoomChanged: ((CGFloat) -> Void)?) {
            self.onZoomChanged = onZoomChanged
        }

        func loadImage(imageURL: URL?, localURL: URL?) {
            // Try local file first
            if let localURL, let data = try? Data(contentsOf: localURL), let image = UIImage(data: data) {
                applyImage(image)
                return
            }

            // Fall back to remote URL
            guard let imageURL else { return }
            Task { @MainActor in
                if let image = try? await ImagePipeline.shared.image(for: imageURL) {
                    self.applyImage(image)
                }
            }
        }

        private func applyImage(_ image: UIImage) {
            imageView?.image = image
            imageView?.frame = CGRect(origin: .zero, size: image.size)
            scrollView?.contentSize = image.size
            fitToView()
        }

        func fitToView() {
            guard let scrollView, let imageView, let image = imageView.image else { return }
            let scrollViewSize = scrollView.bounds.size
            let imageSize = image.size
            let widthRatio = scrollViewSize.width / imageSize.width
            let heightRatio = scrollViewSize.height / imageSize.height
            let scale = min(widthRatio, heightRatio)
            scrollView.setZoomScale(scale, animated: false)
            centerImage()
        }

        func centerImage() {
            guard let scrollView, let imageView else { return }
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            imageView.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + offsetX,
                y: scrollView.contentSize.height * 0.5 + offsetY
            )
        }

        // MARK: - UIScrollViewDelegate

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
            onZoomChanged?(scrollView.zoomScale)
        }

        // MARK: - Double-tap

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale * 1.5 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: scrollView)
                let scale = scrollView.maximumZoomScale
                let rect = CGRect(
                    x: point.x - scrollView.bounds.width / (2 * scale),
                    y: point.y - scrollView.bounds.height / (2 * scale),
                    width: scrollView.bounds.width / scale,
                    height: scrollView.bounds.height / scale
                )
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}
#endif
