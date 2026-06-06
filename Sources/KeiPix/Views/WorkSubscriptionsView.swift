import SwiftUI

struct WorkSubscriptionsView: View {
    @Bindable var store: KeiPixStore
    @State private var searchText = ""
    @State private var isChecking = false
    @State private var actionMessage: String?

    private let gridLayout = NativeAdaptiveGridCollectionLayout(
        minimumItemWidth: 280,
        maximumItemWidth: 400,
        itemHeight: 118
    )

    private var filteredSubscriptions: [WorkSubscription] {
        store.subscriptionItems(matching: searchText)
    }

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else {
                VStack(spacing: 0) {
                    header
                        .platformGlassControlBar(verticalPadding: 8, topPadding: 2)

                    content
                }
            }
        }
        .platformPageHeader(
            title: L10n.workSubscriptions,
            status: subtitle,
            statusSystemImage: "bell.badge"
        )
        .platformPageNavigationChrome(title: L10n.workSubscriptions, status: subtitle)
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
        GlassEffectContainer(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    subscriptionSearchField
                        .frame(minWidth: 220, idealWidth: 320, maxWidth: 520)
                    subscriptionActionRail
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 10) {
                    subscriptionSearchField
                    subscriptionActionRail
                }
            }
        }
        .controlSize(.small)
    }

    private var subscriptionSearchField: some View {
        OS26LibrarySearchField(
            text: $searchText,
            placeholder: L10n.searchHistory,
            minWidth: 180,
            idealWidth: 260,
            maxWidth: 420
        )
    }

    private var subscriptionActionRail: some View {
        OS26LibraryActionRail {
            Button {
                searchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .os26GlassIconButton()
            .disabled(searchText.isEmpty)
            .help(L10n.clearSearch)

            Button {
                Task { await checkForUpdates() }
            } label: {
                Label(
                    L10n.workSubscriptionsCheckNow,
                    systemImage: isChecking ? "arrow.triangle.2.circlepath" : "arrow.clockwise"
                )
            }
            .os26GlassIconButton()
            .help(L10n.workSubscriptionsCheckNow)
            .disabled(isChecking || store.session == nil)
        }
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
            NativeAdaptiveGridCollectionView(
                items: filteredSubscriptions,
                layout: gridLayout
            ) { subscription in
                AnyView(
                    SubscriptionCard(
                        subscription: subscription,
                        showContentBadges: store.showContentBadges,
                        select: {
                            selectSubscription(subscription)
                        },
                        unsubscribe: {
                            store.workSubscriptions.removeAll { $0.id == subscription.id }
                            store.saveSubscriptions()
                            actionMessage = L10n.workSubscriptionsUnsubscribed
                        }
                    )
                )
            }
        }
    }

    private var subtitle: String {
        guard store.session != nil else { return "" }
        let count = filteredSubscriptions.count
        let newCount = filteredSubscriptions.reduce(0) { $0 + $1.newArtworkCount }
        var parts = [count.formatted()]
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
                                .foregroundStyle(.tint)
                                .glassEffect(.regular, in: Capsule(style: .continuous))
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
        .keiInteractiveGlass(16)
        .contextMenu {
            Button(L10n.workSubscriptionsUnsubscribe, role: .destructive, action: unsubscribe)
        }
    }
}
