import Foundation
import Testing
@testable import KeiPix

struct CreatorCollectionTests {
    @Test("Pinned creator library keeps newest pins first")
    func pinnedCreatorLibraryKeepsNewestPinsFirst() {
        var library = PinnedCreatorLibrary()
        library.pin(Self.user(id: 1, name: "Alice"), addedAt: Date(timeIntervalSince1970: 10))
        library.pin(Self.user(id: 2, name: "Bob"), addedAt: Date(timeIntervalSince1970: 20))

        #expect(library.sortedCreators.map(\.id) == [2, 1])
        #expect(library.contains(userID: 1))
    }

    @Test("Pinned creator library updates existing creator metadata")
    func pinnedCreatorLibraryUpdatesExistingCreatorMetadata() {
        var library = PinnedCreatorLibrary()
        library.pin(Self.user(id: 1, name: "Alice"), addedAt: Date(timeIntervalSince1970: 10))
        library.pin(Self.user(id: 1, name: "Alice Prime", account: "alice_prime"), addedAt: Date(timeIntervalSince1970: 20))

        #expect(library.creators.count == 1)
        #expect(library.sortedCreators.first?.name == "Alice Prime")
        #expect(library.sortedCreators.first?.account == "alice_prime")
    }

    @Test("Pinned creator library removes creators by id")
    func pinnedCreatorLibraryRemovesCreatorsByID() {
        var library = PinnedCreatorLibrary()
        library.pin(Self.user(id: 1, name: "Alice"))
        let firstRemoval = library.unpin(userID: 1)
        let secondRemoval = library.unpin(userID: 1)

        #expect(firstRemoval)
        #expect(library.contains(userID: 1) == false)
        #expect(secondRemoval == false)
    }

    @Test("Visual QA creator profile includes related creators and recent works")
    func visualQACreatorProfileFixture() {
        let detail = VisualQASampleData.creatorProfileDetail

        #expect(detail.user.id == 5001)
        #expect(detail.profile.totalIllusts > 0)
        #expect(VisualQASampleData.creatorProfileRecentWorks.isEmpty == false)
        #expect(VisualQASampleData.creatorProfileRelatedUsers.count >= 2)
    }

    private static func user(id: Int, name: String, account: String? = nil) -> PixivUser {
        PixivUser(
            id: id,
            name: name,
            account: account ?? name.lowercased(),
            avatarURL: URL(string: "https://i.pximg.net/user-profile/img/\(id).jpg"),
            isFollowed: false
        )
    }
}
