import Testing
@testable import KeiPix

@Suite("Mobile bottom tab configuration")
struct MobileBottomTabConfigurationTests {
    @Test("Default iPhone bottom tabs keep three customizable destinations")
    func defaultItemsKeepThreeCustomizableDestinations() {
        #expect(MobileBottomTabConfiguration.defaultItems == [.illustrations, .manga, .publicBookmarks])
        #expect(MobileBottomTabConfiguration.defaultItems.count == MobileBottomTabConfiguration.maximumCustomItemCount)
        #expect(MobileBottomTabConfiguration.defaultItems.contains(.downloads) == false)
        #expect(MobileBottomTabConfiguration.defaultItems.contains(.settings) == false)
    }

    @Test("Stored tab ids are sanitized and backfilled to five visible tabs with Feed and Search")
    func storedIDsAreSanitizedAndBackfilled() {
        let items = MobileBottomTabConfiguration.items(from: "downloads,downloads,settings,unknown")

        #expect(items == [.downloads, .settings, .illustrations])
        #expect(items.count == MobileBottomTabConfiguration.maximumCustomItemCount)
        #expect(Set(items).count == items.count)
    }

    @Test("Replacing a slot keeps exactly three unique custom items")
    func replacingSlotKeepsExactlyThreeUniqueItems() {
        let updated = MobileBottomTabConfiguration.replacing(
            itemAt: 1,
            with: .spotlight,
            in: [.illustrations, .manga, .publicBookmarks]
        )

        #expect(updated == [.illustrations, .spotlight, .publicBookmarks])
        #expect(updated.count == MobileBottomTabConfiguration.maximumCustomItemCount)
        #expect(Set(updated).count == updated.count)
    }

    @Test("Replacing with an existing item preserves uniqueness by swapping positions")
    func replacingWithExistingItemSwapsPositions() {
        let updated = MobileBottomTabConfiguration.replacing(
            itemAt: 0,
            with: .publicBookmarks,
            in: [.illustrations, .manga, .publicBookmarks]
        )

        #expect(updated == [.publicBookmarks, .manga, .illustrations])
        #expect(Set(updated).count == updated.count)
    }
}
