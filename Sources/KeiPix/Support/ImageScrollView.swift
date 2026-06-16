#if os(macOS)
import AppKit
import SwiftUI

/// NSScrollView-based image viewer with native zoom, pan, and inertial scrolling.
///
/// SwiftUI still owns reader state and chrome; AppKit owns the hot image
/// interaction path so magnification, rubber-banding, and document scrolling
/// stay inside the platform view that was built for it.
struct ImageScrollView: NSViewRepresentable {
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

    func makeNSView(context: Context) -> NativeImageScrollView {
        let scrollView = NativeImageScrollView()
        let imageView = NSImageView()

        imageView.imageAlignment = .alignCenter
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.wantsLayer = true
        imageView.layer?.contentsGravity = .resizeAspect

        scrollView.documentView = imageView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.allowsMagnification = true
        scrollView.scrollerStyle = .overlay
        scrollView.minMagnification = 0.05
        scrollView.maxMagnification = ArtworkReaderInteractionState.maximumScale
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        scrollView.onReaderScroll = { event in
            context.coordinator.handleReaderScroll(event)
        }
        scrollView.onSmartMagnify = {
            context.coordinator.toggleSmartZoom(animated: true)
            return true
        }
        scrollView.onLayout = {
            context.coordinator.refitAfterViewportChangeIfNeeded()
        }
        scrollView.onMagnificationChanged = { magnification in
            context.coordinator.handleMagnificationChanged(magnification)
        }
        scrollView.shouldForwardScrollToParent = { event in
            context.coordinator.shouldForwardScrollToParent(event)
        }

        let doubleClick = NSClickGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleClick(_:))
        )
        doubleClick.numberOfClicksRequired = 2
        scrollView.addGestureRecognizer(doubleClick)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.reloadIfNeeded(imageURL: imageURL, localURL: localURL, force: true)

        return scrollView
    }

    func updateNSView(_ scrollView: NativeImageScrollView, context: Context) {
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

    @MainActor
    final class Coordinator: NSObject {
        weak var scrollView: NativeImageScrollView?
        weak var imageView: NSImageView?

        var onImageLoaded: ((PlatformImage) -> Void)?
        var onZoomChanged: ((CGFloat) -> Void)?
        var onPageSwipe: ((ReaderScrollEvent) -> Bool)?

        private var currentLoadKey = ""
        private var lastResetZoomTrigger = 0
        private var lastToggleZoomTrigger = 0
        private var fitMagnification: CGFloat = 1
        private var lastViewportSize: CGSize = .zero
        private var lastReportedLogicalZoom: CGFloat?

        private static let viewportSizeTolerance: CGFloat = 1
        private static let zoomReportTolerance: CGFloat = 0.005

        init(
            onImageLoaded: ((PlatformImage) -> Void)?,
            onZoomChanged: ((CGFloat) -> Void)?,
            onPageSwipe: ((ReaderScrollEvent) -> Bool)?
        ) {
            self.onImageLoaded = onImageLoaded
            self.onZoomChanged = onZoomChanged
            self.onPageSwipe = onPageSwipe
        }

        func reloadIfNeeded(imageURL: URL?, localURL: URL?, force: Bool = false) {
            let loadKey = Self.loadKey(imageURL: imageURL, localURL: localURL)
            guard force || loadKey != currentLoadKey else { return }
            currentLoadKey = loadKey

            Task { @MainActor [weak self] in
                guard let self else { return }
                if let localURL,
                   let localImage = try? await ImagePipeline.shared.image(contentsOf: localURL) {
                    guard Self.loadKey(imageURL: imageURL, localURL: localURL) == currentLoadKey else { return }
                    applyImage(localImage)
                    return
                }

                guard let imageURL else {
                    guard Self.loadKey(imageURL: imageURL, localURL: localURL) == currentLoadKey else { return }
                    imageView?.image = nil
                    return
                }

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

        func handleReaderScroll(_ event: ReaderScrollEvent) -> Bool {
            guard logicalZoomScale <= 1.01 else { return false }
            return onPageSwipe?(event) ?? false
        }

        func shouldForwardScrollToParent(_ event: ReaderScrollEvent) -> Bool {
            guard logicalZoomScale <= 1.01 else { return false }
            return abs(event.deltaY) > abs(event.deltaX) * ArtworkReaderInteractionState.horizontalDominance
        }

        func refitAfterViewportChangeIfNeeded() {
            guard let scrollView else { return }
            let size = scrollView.contentSize
            guard size.width > 0,
                  size.height > 0,
                  Self.isMeaningfullyDifferent(size, from: lastViewportSize) else {
                return
            }
            lastViewportSize = size
            updateFitMagnification(preservingLogicalZoom: true)
        }

        @objc func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
            toggleSmartZoom(animated: true)
        }

        func resetZoom(animated: Bool) {
            setMagnification(fitMagnification, animated: animated)
        }

        func toggleSmartZoom(animated: Bool) {
            let target = logicalZoomScale > 1.35
                ? fitMagnification
                : min(fitMagnification * ArtworkReaderInteractionState.smartZoomScale, scrollView?.maxMagnification ?? 4)
            setMagnification(target, animated: animated)
        }

        private var logicalZoomScale: CGFloat {
            guard let scrollView, fitMagnification > 0 else { return 1 }
            return max(1, scrollView.magnification / fitMagnification)
        }

        private func applyImage(_ image: NSImage) {
            guard let imageView, let scrollView else { return }
            let size = Self.displaySize(for: image)

            imageView.image = image
            imageView.frame = CGRect(origin: .zero, size: size)
            scrollView.documentView = imageView
            scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            lastViewportSize = .zero
            lastReportedLogicalZoom = nil
            updateFitMagnification(preservingLogicalZoom: false)
            onImageLoaded?(image)
        }

        private func updateFitMagnification(preservingLogicalZoom: Bool) {
            guard let scrollView,
                  let imageView,
                  imageView.image != nil,
                  imageView.bounds.width > 0,
                  imageView.bounds.height > 0 else {
                return
            }

            let previousLogicalZoom = logicalZoomScale
            let widthRatio = scrollView.contentSize.width / imageView.bounds.width
            let heightRatio = scrollView.contentSize.height / imageView.bounds.height
            fitMagnification = min(max(min(widthRatio, heightRatio, 1.0), 0.05), 1.0)
            scrollView.minMagnification = fitMagnification
            scrollView.maxMagnification = max(fitMagnification * ArtworkReaderInteractionState.maximumScale, ArtworkReaderInteractionState.maximumScale)

            let nextLogicalZoom = preservingLogicalZoom ? previousLogicalZoom : 1
            setMagnification(fitMagnification * nextLogicalZoom, animated: false)
        }

        private func setMagnification(_ value: CGFloat, animated: Bool) {
            guard let scrollView else { return }
            let clamped = min(max(value, scrollView.minMagnification), scrollView.maxMagnification)
            if animated {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.18
                    scrollView.animator().magnification = clamped
                } completionHandler: { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.centerDocument()
                    }
                }
            } else {
                scrollView.magnification = clamped
            }
            centerDocument()
            reportZoom(magnification: clamped)
        }

        func handleMagnificationChanged(_ magnification: CGFloat) {
            centerDocument()
            reportZoom(magnification: magnification)
        }

        private func centerDocument() {
            guard let scrollView,
                  let imageView,
                  imageView.bounds.width > 0,
                  imageView.bounds.height > 0 else {
                return
            }
            let scaledSize = CGSize(
                width: imageView.bounds.width * scrollView.magnification,
                height: imageView.bounds.height * scrollView.magnification
            )
            let horizontalInset = max((scrollView.contentSize.width - scaledSize.width) * 0.5, 0)
            let verticalInset = max((scrollView.contentSize.height - scaledSize.height) * 0.5, 0)
            scrollView.contentInsets = NSEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }

        func reportZoom(magnification: CGFloat) {
            guard fitMagnification > 0 else { return }
            let logicalZoom = max(1, magnification / fitMagnification)
            if let lastReportedLogicalZoom,
               abs(logicalZoom - lastReportedLogicalZoom) <= Self.zoomReportTolerance {
                return
            }
            lastReportedLogicalZoom = logicalZoom
            onZoomChanged?(logicalZoom)
        }

        private static func loadKey(imageURL: URL?, localURL: URL?) -> String {
            "\(localURL?.path(percentEncoded: false) ?? "")|\(imageURL?.absoluteString ?? "")"
        }

        private static func displaySize(for image: NSImage) -> CGSize {
            if let representation = image.representations.max(by: { lhs, rhs in
                lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
            }), representation.pixelsWide > 0, representation.pixelsHigh > 0 {
                return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
            }

            let size = image.size
            if size.width > 0, size.height > 0 {
                return size
            }
            return CGSize(width: 1, height: 1)
        }

        private static func isMeaningfullyDifferent(_ lhs: CGSize, from rhs: CGSize) -> Bool {
            abs(lhs.width - rhs.width) > viewportSizeTolerance
                || abs(lhs.height - rhs.height) > viewportSizeTolerance
        }
    }
}

final class NativeImageScrollView: NSScrollView {
    var onReaderScroll: (@MainActor (ReaderScrollEvent) -> Bool)?
    var onSmartMagnify: (@MainActor () -> Bool)?
    var onLayout: (@MainActor () -> Void)?
    var onMagnificationChanged: (@MainActor (CGFloat) -> Void)?
    var shouldForwardScrollToParent: (@MainActor (ReaderScrollEvent) -> Bool)?

    override func scrollWheel(with event: NSEvent) {
        let multiplier: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 10
        let readerEvent = ReaderScrollEvent(
            deltaX: event.scrollingDeltaX * multiplier,
            deltaY: event.scrollingDeltaY * multiplier,
            isFinished: event.phase.contains(.ended) || event.phase.contains(.cancelled),
            isMomentum: event.momentumPhase.isEmpty == false
        )

        if onReaderScroll?(readerEvent) == true {
            return
        }
        if shouldForwardScrollToParent?(readerEvent) == true {
            if let nextResponder {
                nextResponder.scrollWheel(with: event)
            } else {
                super.scrollWheel(with: event)
            }
            return
        }
        super.scrollWheel(with: event)
    }

    override func smartMagnify(with event: NSEvent) {
        guard onSmartMagnify?() == true else {
            super.smartMagnify(with: event)
            return
        }
    }

    override func magnify(with event: NSEvent) {
        super.magnify(with: event)
        onMagnificationChanged?(magnification)
    }

    override func layout() {
        super.layout()
        onLayout?()
    }
}
#endif
