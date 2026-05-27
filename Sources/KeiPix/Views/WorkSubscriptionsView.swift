import SwiftUI

struct WorkSubscriptionsView: View {
    @Bindable var store: KeiPixStore
    @State private var searchText = ""
    @State private var isChecking = false
    @State private var actionMessage: String?

    private var filteredSubscriptions: [WorkSubscription] {
        store.subscriptionItems(matching: searchText)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.bar)

            Divider()

            content
        }
        .navigationTitle(L10n.workSubscriptions)
        .navigationSubtitle(subtitle)
        .overlay(alignment: .bottom) {
            if let actionMessage {
                FloatingStatusBanner(maxWidth: 520) {
                    Text(actionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
    }

    private var header: some View {
        FlowLayout(spacing: 8) {
            TextField(L10n.searchHistory, text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)

            Button {
                searchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(searchText.isEmpty)
            .help(L10n.clearSearch)

            Spacer(minLength: 0)

            Button {
                Task { await checkForUpdates() }
            } label: {
                Label(L10n.workSubscriptionsCheckNow, systemImage: "arrow.clockwise")
            }
            .disabled(isChecking || store.session == nil)
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var content: some View {
        if filteredSubscriptions.isEmpty {
            EmptyStateView(
                title: searchText.isEmpty ? L10n.workSubscriptionsEmpty : L10n.noMatchingHistoryTitle,
                subtitle: searchText.isEmpty ? L10n.workSubscriptionsEmptyHint : L10n.noMatchingHistorySubtitle,
                systemImage: "bell.badge"
            )
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(filteredSubscriptions) { subscription in
                        SubscriptionCard(
                            subscription: subscription,
                            showContentBadges: store.showContentBadges,
                            select: {
                                Task { await selectSubscription(subscription) }
                            },
                            unsubscribe: {
                                store.workSubscriptions.removeAll { $0.id == subscription.id }
                                store.saveSubscriptions()
                                actionMessage = L10n.workSubscriptionsUnsubscribed
                            }
                        )
                    }
                }
                .padding(18)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 14)]
    }

    private var subtitle: String {
        let count = filteredSubscriptions.count
        let newCount = filteredSubscriptions.reduce(0) { $0 + $1.newArtworkCount }
        var parts = ["\(count) \(L10n.results)"]
        if newCount > 0 {
            parts.append("\(newCount) \(L10n.workSubscriptionsNewWorks)")
        }
        return parts.joined(separator: " · ")
    }

    private func checkForUpdates() async {
        isChecking = true
        await store.checkSubscriptionsForUpdates()
        isChecking = false
        let newCount = store.workSubscriptions.reduce(0) { $0 + $1.newArtworkCount }
        if newCount > 0 {
            actionMessage = "\(newCount) \(L10n.workSubscriptionsNewWorks)"
        }
    }

    private func selectSubscription(_ subscription: WorkSubscription) {
        store.clearSubscriptionNewCount(for: subscription)
        let user = PixivUser(
            id: subscription.creatorID,
            name: subscription.creatorName,
            account: subscription.creatorAccount
        )
        store.focusedUser = user
        store.selectedRoute = .search
        store.searchText = "user:\(subscription.creatorAccount)"
    }
}

private struct SubscriptionCard: View {
    let subscription: WorkSubscription
    let showContentBadges: Bool
    let select: () -> Void
    let unsubscribe: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                RemoteImageView(url: subscription.creatorThumbnailURL)
                    .frame(width: 56, height: 56)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(subscription.creatorName)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)

                        if subscription.newArtworkCount > 0 {
                            Text("\(subscription.newArtworkCount)")
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.tint, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }

                    Text("@\(subscription.creatorAccount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let lastChecked = subscription.lastCheckedAt {
                        Text("\(L10n.workSubscriptionsLastChecked): \(lastChecked.formatted(.relative(presentation: .named)))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
            .padding(12)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(12)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.separator.opacity(0.4), lineWidth: 1)
        }
        .contextMenu {
            Button(L10n.workSubscriptionsUnsubscribed, role: .destructive, action: unsubscribe)
        }
    }
}
