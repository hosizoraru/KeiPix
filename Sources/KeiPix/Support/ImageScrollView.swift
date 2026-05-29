#if os(macOS)
import AppKit
import SwiftUI

/// NSScrollView-based image viewer with smooth zoom/pan.
///
/// Replaces SwiftUI's `scaleEffect` + `offset` approach with native
/// `NSScrollView` magnification that provides:
/// - Inertia scrolling and rubber-banding
/// - Smooth pinch-to-zoom with center point control
/// - Double-tap to toggle zoom
/// - Better trackpad gesture handling
struct ImageScrollView: NSViewRepresentable {
    let imageURL: URL?
    let localURL: URL?
    let onImageLoaded: ((PlatformImage) -> Void)?
    let onZoomChanged: ((CGFloat) -> Void)?

    init(
        imageURL: URL?,
        localURL: URL? = nil,
        onImageLoaded: ((PlatformImage) -> Void)? = nil,
        onZoomChanged: ((CGFloat) -> Void)? = nil
    ) {
        self.imageURL = imageURL
        self.localURL = localURL
        self.onImageLoaded = onImageLoaded
        self.onZoomChanged = onZoomChanged
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.imageAlignment = .alignCenter

        scrollView.documentView = imageView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 1.0
        scrollView.maxMagnification = 4.0
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView

        // Load the image
        context.coordinator.loadImage(imageURL: imageURL, localURL: localURL)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator

        // Only reload if URL changed
        if coordinator.currentImageURL != imageURL {
            coordinator.currentImageURL = imageURL
            coordinator.loadImage(imageURL: imageURL, localURL: localURL)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onImageLoaded: onImageLoaded,
            onZoomChanged: onZoomChanged
        )
    }

    class Coordinator {
        var scrollView: NSScrollView?
        var imageView: NSImageView?
        var currentImageURL: URL?
        let onImageLoaded: ((PlatformImage) -> Void)?
        let onZoomChanged: ((CGFloat) -> Void)?

        init(
            onImageLoaded: ((PlatformImage) -> Void)?,
            onZoomChanged: ((CGFloat) -> Void)?
        ) {
            self.onImageLoaded = onImageLoaded
            self.onZoomChanged = onZoomChanged
        }

        @MainActor
        func loadImage(imageURL: URL?, localURL: URL?) {
            // Try local file first
            if let localURL, let image = NSImage(contentsOf: localURL) {
                applyImage(image)
                return
            }

            // Fall back to remote URL
            guard let imageURL else { return }

            Task {
                if let image = try? await ImagePipeline.shared.image(for: imageURL) {
                    self.applyImage(image)
                }
            }
        }

        private func applyImage(_ image: NSImage) {
            imageView?.image = image
            onImageLoaded?(image)

            // Fit image to scroll view
            if let scrollView {
                let imageSize = image.size
                let scrollViewSize = scrollView.contentSize
                let widthRatio = scrollViewSize.width / imageSize.width
                let heightRatio = scrollViewSize.height / imageSize.height
                let scale = min(widthRatio, heightRatio, 1.0)
                scrollView.magnification = scale
            }
        }
    }
}

// MARK: - Zoom controls

extension ImageScrollView {
    /// Reset zoom to fit the image in the scroll view.
    static func resetZoom(_ scrollView: NSScrollView) {
        guard let imageView = scrollView.documentView as? NSImageView,
              let image = imageView.image else { return }

        let imageSize = image.size
        let scrollViewSize = scrollView.contentSize
        let widthRatio = scrollViewSize.width / imageSize.width
        let heightRatio = scrollViewSize.height / imageSize.height
        let scale = min(widthRatio, heightRatio, 1.0)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            scrollView.animator().magnification = scale
        }
    }

    /// Toggle between fit and 2x zoom.
    static func toggleZoom(_ scrollView: NSScrollView) {
        guard let imageView = scrollView.documentView as? NSImageView,
              let image = imageView.image else { return }

        let imageSize = image.size
        let scrollViewSize = scrollView.contentSize
        let widthRatio = scrollViewSize.width / imageSize.width
        let heightRatio = scrollViewSize.height / imageSize.height
        let fitScale = min(widthRatio, heightRatio, 1.0)

        let targetScale = scrollView.magnification > fitScale * 1.5 ? fitScale : fitScale * 2.0

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            scrollView.animator().magnification = targetScale
        }
    }
}
#endif
