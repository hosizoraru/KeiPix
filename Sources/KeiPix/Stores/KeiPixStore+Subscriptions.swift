import Foundation

extension KeiPixStore {
    private static let storageKey = "workSubscriptions"

    static func loadSubscriptions() -> [WorkSubscription] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([WorkSubscription].self, from: data)) ?? []
    }

    func saveSubscriptions() {
        guard let data = try? JSONEncoder().encode(workSubscriptions) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }

    func isSubscribed(to user: PixivUser) -> Bool {
        workSubscriptions.contains { $0.creatorID == user.id }
    }

    func subscribe(to user: PixivUser) {
        guard isSubscribed(to: user) == false else { return }
        var sub = WorkSubscription(
            creatorID: user.id,
            creatorName: user.name,
            creatorAccount: user.account,
            creatorThumbnailURL: user.avatarURL
        )
        sub.lastCheckedAt = Date()
        workSubscriptions.append(sub)
        saveSubscriptions()
    }

    func unsubscribe(from user: PixivUser) {
        workSubscriptions.removeAll { $0.creatorID == user.id }
        saveSubscriptions()
    }

    func toggleSubscription(for user: PixivUser) {
        if isSubscribed(to: user) {
            unsubscribe(from: user)
        } else {
            subscribe(to: user)
        }
    }

    func checkSubscriptionsForUpdates() async {
        guard session != nil else { return }
        var hasChanges = false

        for index in workSubscriptions.indices {
            let sub = workSubscriptions[index]
            do {
                let response = try await api.userIllusts(userID: sub.creatorID, type: "illust")
                let artworkIDs = response.illusts.map(\.id)
                let newIDs = artworkIDs.filter { sub.lastSeenArtworkIDs.contains($0) == false }

                if sub.lastSeenArtworkIDs.isEmpty {
                    // First check — just record the IDs, don't count as new
                    workSubscriptions[index].lastSeenArtworkIDs = artworkIDs
                } else if newIDs.isEmpty == false {
                    workSubscriptions[index].lastSeenArtworkIDs = artworkIDs
                    workSubscriptions[index].newArtworkCount += newIDs.count
                    hasChanges = true
                }

                workSubscriptions[index].lastCheckedAt = Date()
            } catch {
                // Skip failed checks silently
                continue
            }
        }

        if hasChanges {
            saveSubscriptions()
        }
    }

    func clearSubscriptionNewCount(for subscription: WorkSubscription) {
        guard let index = workSubscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        workSubscriptions[index].newArtworkCount = 0
        saveSubscriptions()
    }

    func subscriptionItems(matching searchText: String) -> [WorkSubscription] {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        guard trimmed.isEmpty == false else { return workSubscriptions }
        let lower = trimmed.lowercased()
        return workSubscriptions.filter {
            $0.creatorName.lowercased().contains(lower)
            || $0.creatorAccount.lowercased().contains(lower)
        }
    }
}
