import Foundation

@MainActor
extension KeiPixStore {
    var pinnedCreatorPreviews: [PixivUserPreview] {
        pinnedCreatorLibrary.sortedCreators.map { creator in
            let user = PixivUser(
                id: creator.id,
                name: creator.name,
                account: creator.account,
                avatarURL: creator.avatarURL,
                isFollowed: creator.isFollowed
            )
            return PixivUserPreview(
                user: user,
                illusts: [],
                isMuted: mutedUsers[creator.id] != nil
            )
        }
    }

    func isPinnedCreator(_ user: PixivUser) -> Bool {
        pinnedCreatorLibrary.contains(userID: user.id)
    }

    @discardableResult
    func pinCreator(_ user: PixivUser) -> Bool {
        guard pinnedCreatorLibrary.contains(userID: user.id) == false else {
            pinnedCreatorLibrary.pin(user)
            savePinnedCreatorLibrary()
            return false
        }
        pinnedCreatorLibrary.pin(user)
        savePinnedCreatorLibrary()
        return true
    }

    @discardableResult
    func unpinCreator(_ user: PixivUser) -> Bool {
        let removed = pinnedCreatorLibrary.unpin(userID: user.id)
        if removed {
            savePinnedCreatorLibrary()
        }
        return removed
    }

    @discardableResult
    func togglePinnedCreator(_ user: PixivUser) -> Bool {
        if isPinnedCreator(user) {
            unpinCreator(user)
            return false
        }
        pinCreator(user)
        return true
    }

    func updatePinnedCreatorFollowState(user: PixivUser, isFollowed: Bool) {
        guard let index = pinnedCreatorLibrary.creators.firstIndex(where: { $0.id == user.id }) else {
            return
        }
        pinnedCreatorLibrary.creators[index].isFollowed = isFollowed
        pinnedCreatorLibrary.creators[index].name = user.name
        pinnedCreatorLibrary.creators[index].account = user.account
        pinnedCreatorLibrary.creators[index].avatarURL = user.avatarURL
        savePinnedCreatorLibrary()
    }

    static func loadPinnedCreatorLibrary() -> PinnedCreatorLibrary {
        guard let data = UserDefaults.standard.data(forKey: "pinnedCreatorLibrary") else {
            return PinnedCreatorLibrary()
        }
        return (try? JSONDecoder().decode(PinnedCreatorLibrary.self, from: data)) ?? PinnedCreatorLibrary()
    }

    private func savePinnedCreatorLibrary() {
        guard let data = try? JSONEncoder().encode(pinnedCreatorLibrary) else { return }
        UserDefaults.standard.set(data, forKey: "pinnedCreatorLibrary")
    }
}
