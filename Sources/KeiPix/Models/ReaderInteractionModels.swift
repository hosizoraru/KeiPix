import CoreGraphics
import Foundation
import Observation

enum TrackpadHorizontalSwipeBehavior: String, CaseIterable, Identifiable {
    case pageOnly
    case pageThenArtworkAtEdges

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pageOnly:
            L10n.pageOnlySwipe
        case .pageThenArtworkAtEdges:
            L10n.pageThenArtworkSwipe
        }
    }
}

@MainActor
@Observable
final class ArtworkReaderInteractionState {
    nonisolated static let minimumScale: CGFloat = 1
    nonisolated static let maximumScale: CGFloat = 4
    nonisolated static let smartZoomScale: CGFloat = 2.25
    nonisolated static let resetSnapThreshold: CGFloat = 1.04
    nonisolated static let swipeThreshold: CGFloat = 90
    nonisolated static let horizontalDominance: CGFloat = 1.35

    var scale: CGFloat = 1
    var offset: CGSize = .zero
    var activePageIndex = 0
    var isGestureLocked = false
    var resetZoomTrigger = 0
    var toggleZoomTrigger = 0

    private var accumulatedSwipe = CGSize.zero

    var isZoomed: Bool {
        scale > 1.01
    }

    func resetZoom() {
        scale = Self.minimumScale
        offset = .zero
        isGestureLocked = false
        resetZoomTrigger += 1
    }

    func toggleSmartZoom(in size: CGSize) {
        if isZoomed {
            resetZoom()
        } else {
            scale = Self.smartZoomScale
            offset = clamped(offset, in: size)
            toggleZoomTrigger += 1
        }
    }

    func updateNativeZoomScale(_ nativeScale: CGFloat) {
        guard nativeScale.isFinite else { return }
        scale = max(Self.minimumScale, nativeScale)
        if isZoomed == false {
            offset = .zero
        }
    }

    func applyMagnification(_ delta: CGFloat, in size: CGSize) {
        guard delta.isFinite else { return }
        let nextScale = (scale * (1 + delta)).clamped(to: Self.minimumScale...Self.maximumScale)
        scale = nextScale
        offset = clamped(offset, in: size)
        isGestureLocked = true
    }

    func finishMagnification() {
        if scale < Self.resetSnapThreshold {
            resetZoom()
        } else {
            isGestureLocked = false
        }
    }

    func applyPan(deltaX: CGFloat, deltaY: CGFloat, in size: CGSize) {
        guard isZoomed else { return }
        let proposed = CGSize(
            width: offset.width - deltaX,
            height: offset.height - deltaY
        )
        offset = clamped(proposed, in: size)
    }

    func trackSwipe(deltaX: CGFloat, deltaY: CGFloat, isFinished: Bool) -> (handled: Bool, pageDelta: Int?) {
        guard abs(deltaX) > abs(deltaY) * Self.horizontalDominance else {
            if isFinished {
                accumulatedSwipe = .zero
            }
            return (false, nil)
        }

        accumulatedSwipe.width += deltaX
        accumulatedSwipe.height += deltaY

        let x = accumulatedSwipe.width
        let y = accumulatedSwipe.height
        let reachedThreshold = abs(x) >= Self.swipeThreshold && abs(x) > abs(y) * Self.horizontalDominance

        if reachedThreshold {
            accumulatedSwipe = .zero
            return (true, x > 0 ? 1 : -1)
        }

        if isFinished {
            accumulatedSwipe = .zero
        }

        return (true, nil)
    }

    private func clamped(_ proposed: CGSize, in size: CGSize) -> CGSize {
        guard isZoomed else { return .zero }
        let maxX = max(0, size.width * (scale - 1) / 2)
        let maxY = max(0, size.height * (scale - 1) / 2)
        return CGSize(
            width: proposed.width.clamped(to: -maxX...maxX),
            height: proposed.height.clamped(to: -maxY...maxY)
        )
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
