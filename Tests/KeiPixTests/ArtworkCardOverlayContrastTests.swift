import Testing
@testable import KeiPix

struct ArtworkCardOverlayContrastTests {
    @Test("Artwork waterfall overlays keep text readable on bright covers")
    func overlayTextContrastIsStrongEnoughForBrightCovers() {
        let contrast = ArtworkCardOverlayContrast.default

        #expect(contrast.titleOpacity >= 0.96)
        #expect(contrast.secondaryOpacity >= 0.82)
        #expect(contrast.metricsOpacity >= 0.80)
        #expect(contrast.scrimBottomOpacity >= 0.82)
        #expect(contrast.textShadowOpacity >= 0.38)
        #expect(contrast.textShadowRadius >= 3)
    }
}
