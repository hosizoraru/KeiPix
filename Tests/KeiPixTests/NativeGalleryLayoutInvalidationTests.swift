import CoreGraphics
import Testing
@testable import KeiPix

struct NativeGalleryLayoutInvalidationTests {
    @Test("Masonry layout does not invalidate for scroll-only bounds changes")
    func scrollOnlyBoundsChangesDoNotInvalidate() {
        #expect(
            NativeGalleryBoundsInvalidation.shouldInvalidate(
                oldSize: CGSize(width: 390, height: 720),
                newSize: CGSize(width: 390, height: 720)
            ) == false
        )
    }

    @Test("Masonry layout invalidates when bounds size changes")
    func sizeChangesInvalidate() {
        #expect(
            NativeGalleryBoundsInvalidation.shouldInvalidate(
                oldSize: CGSize(width: 390, height: 720),
                newSize: CGSize(width: 600, height: 720)
            )
        )
        #expect(
            NativeGalleryBoundsInvalidation.shouldInvalidate(
                oldSize: CGSize(width: 390, height: 720),
                newSize: CGSize(width: 390, height: 820)
            )
        )
    }

    @Test("Masonry layout ignores sub-pixel bounds size jitter")
    func subPixelJitterIsIgnored() {
        #expect(
            NativeGalleryBoundsInvalidation.shouldInvalidate(
                oldSize: CGSize(width: 390, height: 720),
                newSize: CGSize(width: 390.25, height: 720.25)
            ) == false
        )
    }
}
