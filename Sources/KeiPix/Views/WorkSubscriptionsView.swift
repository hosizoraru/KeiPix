import SwiftUI

struct WorkSubscriptionsView: View {
    @Bindable var store: KeiPixStore
    @State private var searchText = ""
    @State private var isSearchPresented = false
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
                    if showsSubscriptionSearchBar {
                        header
                            .platformGlassControlBar(verticalPadding: 7, topPadding: 0)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    content
                }
            }
        }
        .platformPageHeader(
            title: L10n.workSubscriptions,
            status: subtitle,
            statusSystemImage: "bell.badge"
        ) {
            subscriptionTitleActions
        }
        .platformPageNavigationChrome(title: L10n.workSubscriptions, status: subtitle)
        .mobileRouteBadgeCount(filteredSubscriptions.count, for: .workSubscriptions)
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
        .animation(.snappy(duration: 0.18), value: showsSubscriptionSearchBar)
        .task(id: store.routeRefreshGeneration) {
            await checkForUpdates(showFeedback: false)
        }
    }

    private var header: some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 10) {
                subscriptionSearchField
                    .frame(minWidth: 220, idealWidth: 320, maxWidth: 520)
                    .layoutPriority(1)
                Spacer(minLength: 0)
            }
        }
        .controlSize(.small)
    }

    private var subscriptionSearchField: some View {
        OS26LibrarySearchField(
            text: $searchText,
            placeholder: L10n.searchCreatorsInList,
            minWidth: 180,
            idealWidth: 260,
            maxWidth: 420,
            collapsesOnPhone: false
        )
    }

    @ViewBuilder
    private var subscriptionTitleActions: some View {
        if store.session != nil {
            OS26LibraryActionRail {
                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        if showsSubscriptionSearchBar, searchText.isEmpty {
                            isSearchPresented = false
                        } else {
                            isSearchPresented = true
                        }
                    }
                } label: {
                    Label(L10n.search, systemImage: searchText.isEmpty ? "magnifyingglass" : "magnifyingglass.circle.fill")
                }
                .os26GlassIconButton(prominent: showsSubscriptionSearchBar || searchText.isEmpty == false)
                .help(L10n.searchCreatorsInList)
                .accessibilityLabel(L10n.searchCreatorsInList)

                Button {
                    withAnimation(.snappy(duration: 0.16)) {
                        searchText = ""
                        isSearchPresented = false
                    }
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .os26GlassIconButton()
                .disabled(searchText.isEmpty && isSearchPresented == false)
                .help(L10n.clearSearch)
            }
            .controlSize(.small)
        }
    }

    private var showsSubscriptionSearchBar: Bool {
        isSearchPresented || searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
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
                        setTracking: { kind, isTracking in
                            let didChange = store.setSubscription(subscription, tracks: kind, isTracking)
                            if didChange {
                                let title = workSubscriptionKindTitle(kind)
                                actionMessage = String(
                                    format: isTracking
                                        ? L10n.workSubscriptionsTrackingEnabledFormat
                                        : L10n.workSubscriptionsTrackingDisabledFormat,
                                    title
                                )
                            } else {
                                actionMessage = L10n.workSubscriptionsRequiresOneKind
                            }
                            return didChange
                        },
                        unsubscribe: {
                            store.workSubscriptions.removeAll { $0.id == subscription.id }
                            store.saveSubscriptions()
                            actionMessage = L10n.workSubscriptionsUnsubscribed
                        }
                    )
                )
            }
            .nativeBottomTabContentSurface()
        }
    }

    private var subtitle: String {
        guard store.session != nil else { return "" }
        let count = filteredSubscriptions.count
        let newCount = filteredSubscriptions.reduce(0) { $0 + $1.totalNewWorkCount }
        var parts = [count.formatted()]
        if newCount > 0 {
            parts.append("\(newCount) \(L10n.workSubscriptionsNewWorks)")
        }
        return parts.joined(separator: " · ")
    }

    private func checkForUpdates(showFeedback: Bool = true) async {
        guard store.session != nil,
              store.workSubscriptions.isEmpty == false,
              isChecking == false else { return }
        isChecking = true
        defer { isChecking = false }

        await store.checkSubscriptionsForUpdates()
        let newCount = store.workSubscriptions.reduce(0) { $0 + $1.totalNewWorkCount }
        if showFeedback, newCount > 0 {
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
        Task {
            await store.openUserFeed(user: user, route: subscription.preferredCreatorRoute)
        }
    }
}

private struct SubscriptionCard: View {
    let subscription: WorkSubscription
    let showContentBadges: Bool
    let select: () -> Void
    let setTracking: (WorkSubscriptionContentKind, Bool) -> Bool
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

                        if subscription.totalNewWorkCount > 0 {
                            Text("\(subscription.totalNewWorkCount)")
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

                    Text(subscription.trackedKinds.map(workSubscriptionKindTitle).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
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
            Section(L10n.workSubscriptionsTracking) {
                ForEach(WorkSubscriptionContentKind.allCases) { kind in
                    Button {
                        _ = setTracking(kind, subscription.isTracking(kind) == false)
                    } label: {
                        Label(
                            workSubscriptionKindTitle(kind),
                            systemImage: subscription.isTracking(kind) ? "checkmark.circle.fill" : "circle"
                        )
                    }
                }
            }

            Button(L10n.workSubscriptionsUnsubscribe, role: .destructive, action: unsubscribe)
        }
    }
}

private func workSubscriptionKindTitle(_ kind: WorkSubscriptionContentKind) -> String {
    switch kind {
    case .illustrations:
        L10n.illustrations
    case .manga:
        L10n.manga
    case .novels:
        L10n.novels
    }
}
