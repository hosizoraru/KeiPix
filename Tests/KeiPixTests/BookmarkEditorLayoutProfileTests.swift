import CoreGraphics
import Testing
@testable import KeiPix

struct BookmarkEditorLayoutProfileTests {
    @Test("iPhone uses the simplified bookmark editor sheet")
    func iPhoneUsesCompactBookmarkEditor() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 820, height: 620),
            traits: BookmarkEditorViewportTraits(
                isPhone: true,
                horizontalSizeClassIsCompact: false,
                activeWindowSize: CGSize(width: 932, height: 430)
            )
        )

        #expect(profile == .compact)
    }

    @Test("Portrait iPad uses the simplified bookmark editor sheet")
    func portraitIPadUsesCompactBookmarkEditor() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 700, height: 980),
            traits: BookmarkEditorViewportTraits(
                isPhone: false,
                horizontalSizeClassIsCompact: false,
                activeWindowSize: CGSize(width: 834, height: 1194)
            )
        )

        #expect(profile == .compact)
    }

    @Test("Landscape iPad keeps the complete bookmark editor sheet")
    func landscapeIPadUsesExpandedBookmarkEditor() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 540, height: 720),
            traits: BookmarkEditorViewportTraits(
                isPhone: false,
                horizontalSizeClassIsCompact: false,
                activeWindowSize: CGSize(width: 1194, height: 834)
            )
        )

        #expect(profile == .expanded)
    }

    @Test("Landscape scene orientation wins over stale portrait window bounds")
    func landscapeSceneOrientationOverridesStalePortraitBounds() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 834, height: 1194),
            traits: BookmarkEditorViewportTraits(
                isPhone: false,
                horizontalSizeClassIsCompact: false,
                activeWindowSize: CGSize(width: 834, height: 1194),
                interfaceOrientationIsLandscape: true
            )
        )

        #expect(profile == .expanded)
    }

    @Test("Landscape iPad sheet ignores compact modal size class when the window is wide")
    func landscapeIPadSheetIgnoresCompactModalSizeClass() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 760, height: 700),
            traits: BookmarkEditorViewportTraits(
                isPhone: false,
                horizontalSizeClassIsCompact: true,
                activeWindowSize: CGSize(width: 1194, height: 834),
                interfaceOrientationIsLandscape: true
            )
        )

        #expect(profile == .expanded)
    }

    @Test("Landscape screen bounds recover the complete sheet when modal traits are compact")
    func landscapeScreenBoundsRecoverExpandedBookmarkEditor() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 760, height: 700),
            traits: BookmarkEditorViewportTraits(
                isPhone: false,
                horizontalSizeClassIsCompact: true,
                activeWindowSize: CGSize(width: 834, height: 1194),
                interfaceOrientationIsPortrait: true,
                screenSize: CGSize(width: 1194, height: 834)
            )
        )

        #expect(profile == .expanded)
    }

    @Test("Landscape device orientation recovers the complete sheet when scene traits are stale")
    func landscapeDeviceOrientationRecoversExpandedBookmarkEditor() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 760, height: 700),
            traits: BookmarkEditorViewportTraits(
                isPhone: false,
                horizontalSizeClassIsCompact: true,
                activeWindowSize: CGSize(width: 834, height: 1194),
                interfaceOrientationIsPortrait: true,
                screenSize: CGSize(width: 834, height: 1194),
                deviceOrientationIsLandscape: true
            )
        )

        #expect(profile == .expanded)
    }

    @Test("Landscape iPad narrow split view keeps the simplified sheet")
    func landscapeIPadNarrowSplitViewUsesCompactBookmarkEditor() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 500, height: 760),
            traits: BookmarkEditorViewportTraits(
                isPhone: false,
                horizontalSizeClassIsCompact: true,
                activeWindowSize: CGSize(width: 500, height: 760),
                interfaceOrientationIsLandscape: true
            )
        )

        #expect(profile == .compact)
    }

    @Test("Portrait scene orientation wins over stale landscape window bounds")
    func portraitSceneOrientationOverridesStaleLandscapeBounds() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 1194, height: 834),
            traits: BookmarkEditorViewportTraits(
                isPhone: false,
                horizontalSizeClassIsCompact: false,
                activeWindowSize: CGSize(width: 1194, height: 834),
                interfaceOrientationIsPortrait: true
            )
        )

        #expect(profile == .compact)
    }

    @Test("Narrow iPad split view keeps the simplified bookmark editor sheet")
    func narrowIPadSplitViewUsesCompactBookmarkEditor() {
        let profile = BookmarkEditorLayoutProfile.resolve(
            containerSize: CGSize(width: 430, height: 760),
            traits: BookmarkEditorViewportTraits(
                isPhone: false,
                horizontalSizeClassIsCompact: true,
                activeWindowSize: CGSize(width: 430, height: 760)
            )
        )

        #expect(profile == .compact)
    }
}
