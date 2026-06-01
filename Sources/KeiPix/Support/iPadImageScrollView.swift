#if os(iOS)
import UIKit
import SwiftUI

/// UIScrollView-based image viewer for iPadOS.
///
/// The SwiftUI reader owns page index and chrome. UIKit owns image zoom/pan so
/// pinch, bounce, and double-tap behavior stay aligned with platform readers.
struct ImageScrollView: UIViewRepresentable {
    let imageURL: URL?
    let localURL: URL?
    var resetZoomTrigger: Int = 0
    var toggleZoomTrigger: Int = 0
    let onImageLoaded: ((PlatformImage) -> Void)?
    let onZoomChanged: ((CGFloat) -> Void)?
    let onPageSwipe: ((ReaderScrollEvent) -> Bool)?

    init(
        imageURL: URL?,
        localURL: URL? = nil,
        resetZoomTrigger: Int = 0,
        toggleZoomTrigger: Int = 0,
        onImageLoaded: ((PlatformImage) -> Void)? = nil,
        onZoomChanged: ((CGFloat) -> Void)? = nil,
        onPageSwipe: ((ReaderScrollEvent) -> Bool)? = nil
    ) {
        self.imageURL = imageURL
        self.localURL = localURL
        self.resetZoomTrigger = resetZoomTrigger
        self.toggleZoomTrigger = toggleZoomTrigger
        self.onImageLoaded = onImageLoaded
        self.onZoomChanged = onZoomChanged
        self.onPageSwipe = onPageSwipe
    }

    func makeUIView(context: Context) -> NativeImageUIScrollView {
        let scrollView = NativeImageUIScrollView()
        let imageView = UIImageView()

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true

        scrollView.addSubview(imageView)
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 0.05
        scrollView.maximumZoomScale = ArtworkReaderInteractionState.maximumScale
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.bounces = true
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear

        scrollView.panGestureRecognizer.addTarget(
            context.coordinator,
            action: #selector(Coordinator.handlePanGesture(_:))
        )

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        scrollView.onLayout = {
            context.coordinator.refitAfterViewportChangeIfNeeded()
        }

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.reloadIfNeeded(imageURL: imageURL, localURL: localURL, force: true)

        return scrollView
    }

    func updateUIView(_ scrollView: NativeImageUIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.onImageLoaded = onImageLoaded
        coordinator.onZoomChanged = onZoomChanged
        coordinator.onPageSwipe = onPageSwipe
        coordinator.reloadIfNeeded(imageURL: imageURL, localURL: localURL)
        coordinator.applyCommands(
            resetZoomTrigger: resetZoomTrigger,
            toggleZoomTrigger: toggleZoomTrigger
        )
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            onImageLoaded: onImageLoaded,
            onZoomChanged: onZoomChanged,
            onPageSwipe: onPageSwipe
        )
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: NativeImageUIScrollView?
        weak var imageView: UIImageView?

        var onImageLoaded: ((PlatformImage) -> Void)?
        var onZoomChanged: ((CGFloat) -> Void)?
        var onPageSwipe: ((ReaderScrollEvent) -> Bool)?

        private var currentLoadKey = ""
        private var lastResetZoomTrigger = 0
        private var lastToggleZoomTrigger = 0
        private var fitZoomScale: CGFloat = 1
        private var lastViewportSize: CGSize = .zero

        init(
            onImageLoaded: ((PlatformImage) -> Void)?,
            onZoomChanged: ((CGFloat) -> Void)?,
            onPageSwipe: ((ReaderScrollEvent) -> Bool)?
        ) {
            self.onImageLoaded = onImageLoaded
            self.onZoomChanged = onZoomChanged
            self.onPageSwipe = onPageSwipe
        }

        @MainActor
        func reloadIfNeeded(imageURL: URL?, localURL: URL?, force: Bool = false) {
            let loadKey = Self.loadKey(imageURL: imageURL, localURL: localURL)
            guard force || loadKey != currentLoadKey else { return }
            currentLoadKey = loadKey

            if let localURL, let image = UIImage(contentsOf: localURL) {
                applyImage(image)
                return
            }

            guard let imageURL else {
                imageView?.image = nil
                return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                let loadedImage = try? await ImagePipeline.shared.image(for: imageURL)
                guard Self.loadKey(imageURL: imageURL, localURL: localURL) == currentLoadKey else { return }
                if let loadedImage {
                    applyImage(loadedImage)
                }
            }
        }

        func applyCommands(resetZoomTrigger: Int, toggleZoomTrigger: Int) {
            if resetZoomTrigger != lastResetZoomTrigger {
                lastResetZoomTrigger = resetZoomTrigger
                resetZoom(animated: true)
            }
            if toggleZoomTrigger != lastToggleZoomTrigger {
                lastToggleZoomTrigger = toggleZoomTrigger
                toggleSmartZoom(animated: true)
            }
        }

        func refitAfterViewportChangeIfNeeded() {
            guard let scrollView else { return }
            let size = scrollView.bounds.size
            guard size.width > 0, size.height > 0, size != lastViewportSize else { return }
            lastViewportSize = size
            updateFitZoomScale(preservingLogicalZoom: true)
        }

        @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
            guard logicalZoomScale <= 1.01 else { return }
            let translation = gesture.translation(in: gesture.view)
            let state = gesture.state
            let event = ReaderScrollEvent(
                deltaX: translation.x,
                deltaY: translation.y,
                isFinished: state == .ended || state == .cancelled || state == .failed,
                isMomentum: false
            )
            _ = onPageSwipe?(event)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            toggleSmartZoom(animated: true)
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage()
            reportZoom(zoomScale: scrollView.zoomScale)
        }

        func resetZoom(animated: Bool) {
            scrollView?.setZoomScale(fitZoomScale, animated: animated)
            reportZoom(zoomScale: fitZoomScale)
        }

        func toggleSmartZoom(animated: Bool) {
            guard let scrollView else { return }
            if logicalZoomScale > 1.35 {
                resetZoom(animated: animated)
            } else {
                let target = min(
                    fitZoomScale * ArtworkReaderInteractionState.smartZoomScale,
                    scrollView.maximumZoomScale
                )
                scrollView.setZoomScale(target, animated: animated)
                reportZoom(zoomScale: target)
            }
        }

        private var logicalZoomScale: CGFloat {
            guard let scrollView, fitZoomScale > 0 else { return 1 }
            return max(1, scrollView.zoomScale / fitZoomScale)
        }

        @MainActor
        private func applyImage(_ image: UIImage) {
            guard let imageView, let scrollView else { return }
            let size = image.size.width > 0 && image.size.height > 0
                ? image.size
                : CGSize(width: 1, height: 1)

            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: size)
            scrollView.contentSize = size
            updateFitZoomScale(preservingLogicalZoom: false)
            onImageLoaded?(image)
        }

        private func updateFitZoomScale(preservingLogicalZoom: Bool) {
            guard let scrollView,
                  let imageView,
                  imageView.image != nil,
                  imageView.bounds.width > 0,
                  imageView.bounds.height > 0 else {
                return
            }

            let previousLogicalZoom = logicalZoomScale
            let widthRatio = scrollView.bounds.width / imageView.bounds.width
            let heightRatio = scrollView.bounds.height / imageView.bounds.height
            fitZoomScale = min(max(min(widthRatio, heightRatio, 1.0), 0.05), 1.0)
            scrollView.minimumZoomScale = fitZoomScale
            scrollView.maximumZoomScale = max(
                fitZoomScale * ArtworkReaderInteractionState.maximumScale,
                ArtworkReaderInteractionState.maximumScale
            )

            let nextLogicalZoom = preservingLogicalZoom ? previousLogicalZoom : 1
            scrollView.setZoomScale(fitZoomScale * nextLogicalZoom, animated: false)
            centerImage()
            reportZoom(zoomScale: scrollView.zoomScale)
        }

        private func centerImage() {
            guard let scrollView, let imageView else { return }
            let offsetX = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
            let offsetY = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
            imageView.center = CGPoint(
                x: scrollView.contentSize.width * 0.5 + offsetX,
                y: scrollView.contentSize.height * 0.5 + offsetY
            )
        }

        private func reportZoom(zoomScale: CGFloat) {
            guard fitZoomScale > 0 else { return }
            onZoomChanged?(max(1, zoomScale / fitZoomScale))
        }

        private static func loadKey(imageURL: URL?, localURL: URL?) -> String {
            "\(localURL?.path(percentEncoded: false) ?? "")|\(imageURL?.absoluteString ?? "")"
        }
    }
}

final class NativeImageUIScrollView: UIScrollView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
#endif
