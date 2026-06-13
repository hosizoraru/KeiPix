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
            var subscription = workSubscriptions[index]
            var didCheckAnyBucket = false

            for kind in WorkSubscriptionContentKind.allCases {
                do {
                    let workIDs = try await subscriptionWorkIDs(for: kind, userID: subscription.creatorID)
                    _ = subscription.recordSeenWorkIDs(workIDs, for: kind)
                    didCheckAnyBucket = true
                } catch {
                    // Keep other buckets updating when one endpoint is temporarily unavailable.
                    continue
                }
            }

            if didCheckAnyBucket {
                subscription.lastCheckedAt = Date()
                workSubscriptions[index] = subscription
                hasChanges = true
            }
        }

        if hasChanges {
            saveSubscriptions()
        }
    }

    func clearSubscriptionNewCount(for subscription: WorkSubscription) {
        guard let index = workSubscriptions.firstIndex(where: { $0.id == subscription.id }) else { return }
        workSubscriptions[index].clearNewWorkCounts()
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

    private func subscriptionWorkIDs(
        for kind: WorkSubscriptionContentKind,
        userID: Int
    ) async throws -> [Int] {
        switch kind {
        case .illustrations:
            let response = try await api.userIllusts(userID: userID, type: "illust")
            return response.illusts.map(\.id)
        case .manga:
            let response = try await api.userIllusts(userID: userID, type: "manga")
            return response.illusts.map(\.id)
        case .novels:
            let response = try await api.userNovels(userID: userID)
            return response.novels.map(\.id)
        }
    }
}
