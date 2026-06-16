import SwiftUI
#if os(iOS)
import UIKit
#endif

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
        store.subscriptionItems(matching: subscriptionFilterText)
    }

    var body: some View {
        subscriptionsRootWithPageHeader
        .platformPageNavigationChrome(title: L10n.workSubscriptions, status: subtitle)
        .mobileRouteBadgeCount(filteredSubscriptions.count, for: .workSubscriptions)
        .mobilePageFilter(mobileSubscriptionPageFilterSnapshot)
        .toolbar {
            subscriptionToolbar
        }
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

    @ViewBuilder
    private var subscriptionsRoot: some View {
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
    }

    @ViewBuilder
    private var subscriptionsRootWithPageHeader: some View {
        #if os(iOS)
        if usesPhoneSubscriptionFilterPill {
            subscriptionsRoot
                .platformPageHeader(
                    title: L10n.workSubscriptions,
                    status: subtitle,
                    statusSystemImage: "bell.badge"
                )
        } else {
            subscriptionsRoot
                .platformPageHeader(
                    title: L10n.workSubscriptions,
                    status: subtitle,
                    statusSystemImage: "bell.badge"
                ) {
                    subscriptionTitleActions
                }
        }
        #else
        subscriptionsRoot
        .platformPageHeader(
            title: L10n.workSubscriptions,
            status: subtitle,
            statusSystemImage: "bell.badge"
        ) {
            subscriptionTitleActions
        }
        #endif
    }

    @ToolbarContentBuilder
    private var subscriptionToolbar: some ToolbarContent {
        #if os(iOS)
        if usesPhoneSubscriptionFilterPill, store.session != nil {
            ToolbarItem(placement: .primaryAction) {
                subscriptionActionsMenu(usesSystemToolbarChrome: true)
            }
        }
        #else
        ToolbarItem(placement: .secondaryAction) {
            EmptyView()
        }
        #endif
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
            text: subscriptionFilterTextBinding,
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
                if usesPhoneSubscriptionFilterPill == false {
                    Button {
                        withAnimation(.snappy(duration: 0.16)) {
                            if showsSubscriptionSearchBar, normalizedSubscriptionFilterText.isEmpty {
                                isSearchPresented = false
                            } else {
                                isSearchPresented = true
                            }
                        }
                    } label: {
                        Label(
                            L10n.search,
                            systemImage: normalizedSubscriptionFilterText.isEmpty
                                ? "magnifyingglass"
                                : "magnifyingglass.circle.fill"
                        )
                    }
                    .os26GlassIconButton(prominent: showsSubscriptionSearchBar || normalizedSubscriptionFilterText.isEmpty == false)
                    .help(L10n.searchCreatorsInList)
                    .accessibilityLabel(L10n.searchCreatorsInList)

                    Button {
                        clearSubscriptionSearch()
                    } label: {
                        Label(L10n.clearSearch, systemImage: "xmark.circle")
                    }
                    .os26GlassIconButton()
                    .disabled(normalizedSubscriptionFilterText.isEmpty && isSearchPresented == false)
                    .help(L10n.clearSearch)
                }

                subscriptionActionsMenu()
            }
            .controlSize(.small)
        }
    }

    private func subscriptionActionsMenu(usesSystemToolbarChrome: Bool = false) -> some View {
        SubscriptionActionsMenu(
            usesSystemToolbarChrome: usesSystemToolbarChrome,
            hasActiveOptions: hasActiveSubscriptionOptions,
            canShowSearch: usesPhoneSubscriptionFilterPill == false,
            canClearSearch: normalizedSubscriptionFilterText.isEmpty == false || isSearchPresented,
            canCheckUpdates: store.session != nil && store.workSubscriptions.isEmpty == false && isChecking == false,
            isChecking: isChecking,
            showSearch: showSubscriptionSearch,
            clearSearch: clearSubscriptionSearch,
            checkForUpdates: { Task { await checkForUpdates(showFeedback: true) } }
        )
    }

    private var showsSubscriptionSearchBar: Bool {
        if usesPhoneSubscriptionFilterPill {
            return false
        }
        return isSearchPresented || normalizedSubscriptionFilterText.isEmpty == false
    }

    private var hasActiveSubscriptionOptions: Bool {
        normalizedSubscriptionFilterText.isEmpty == false
    }

    private var normalizedSubscriptionFilterText: String {
        subscriptionFilterText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var subscriptionFilterText: String {
        subscriptionFilterTextBinding.wrappedValue
    }

    private var subscriptionFilterTextBinding: Binding<String> {
        Binding {
            #if os(iOS)
            if usesPhoneSubscriptionFilterPill {
                return store.clientFilterQuery
            }
            #endif
            return searchText
        } set: { value in
            #if os(iOS)
            if usesPhoneSubscriptionFilterPill {
                store.clientFilterQuery = value
                return
            }
            #endif
            searchText = value
        }
    }

    private var mobileSubscriptionPageFilterSnapshot: MobilePageFilterSnapshot? {
        #if os(iOS)
        guard usesPhoneSubscriptionFilterPill, store.session != nil, store.workSubscriptions.isEmpty == false else { return nil }
        return MobilePageFilterSnapshot(
            route: .workSubscriptions,
            totalCount: store.workSubscriptions.count,
            visibleCount: filteredSubscriptions.count,
            placeholder: L10n.searchCreatorsInList
        )
        #else
        return nil
        #endif
    }

    private var usesPhoneSubscriptionFilterPill: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone
        #else
        false
        #endif
    }

    @ViewBuilder
    private var content: some View {
        if filteredSubscriptions.isEmpty {
            EmptyStateView(
                title: normalizedSubscriptionFilterText.isEmpty ? L10n.workSubscriptionsEmpty : L10n.noMatchingHistoryTitle,
                subtitle: normalizedSubscriptionFilterText.isEmpty ? L10n.workSubscriptionsEmptyHint : L10n.noMatchingHistorySubtitle,
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
        var parts = [
            hasActiveSubscriptionOptions
                ? "\(count.formatted())/\(store.workSubscriptions.count.formatted())"
                : count.formatted()
        ]
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

    private func clearSubscriptionSearch() {
        withAnimation(.snappy(duration: 0.16)) {
            subscriptionFilterTextBinding.wrappedValue = ""
            isSearchPresented = false
        }
    }

    private func showSubscriptionSearch() {
        withAnimation(.snappy(duration: 0.16)) {
            isSearchPresented = true
        }
    }
}

private struct SubscriptionActionsMenu: View {
    let usesSystemToolbarChrome: Bool
    let hasActiveOptions: Bool
    let canShowSearch: Bool
    let canClearSearch: Bool
    let canCheckUpdates: Bool
    let isChecking: Bool
    let showSearch: () -> Void
    let clearSearch: () -> Void
    let checkForUpdates: () -> Void

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        NativeToolbarMenuButton(
            systemImage: actionsSystemImage,
            accessibilityLabel: L10n.workSubscriptions,
            menu: nativeActionsMenu,
            select: handleNativeAction
        )
        .nativeToolbarMenuButtonChrome(usesSystemToolbarChrome: usesSystemToolbarChrome)
        .help(L10n.workSubscriptions)
        #else
        swiftUIActionsMenu
        #endif
    }

    private var actionsSystemImage: String {
        if isChecking {
            return "arrow.triangle.2.circlepath"
        }
        return ToolbarMenuIcon.pageOptions
    }

    private var swiftUIActionsMenu: some View {
        Menu {
            Section(L10n.viewOptions) {
                Button {
                    showSearch()
                } label: {
                    Label(L10n.search, systemImage: "magnifyingglass")
                }
                .disabled(canShowSearch == false)

                Button {
                    clearSearch()
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .disabled(canClearSearch == false)
            }

            Section(L10n.moreActions) {
                Button {
                    checkForUpdates()
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                    Text(L10n.workSubscriptionsCheckNow)
                }
                .disabled(canCheckUpdates == false)
            }
        } label: {
            Label(L10n.workSubscriptions, systemImage: actionsSystemImage)
        }
        .menuOrder(.fixed)
        .os26GlassIconButton(prominent: hasActiveOptions || isChecking)
        .help(L10n.workSubscriptions)
        .accessibilityLabel(L10n.workSubscriptions)
    }

    #if os(iOS)
    private var nativeActionsMenu: NativeToolbarMenu {
        NativeToolbarMenu(
            title: L10n.workSubscriptions,
            cacheKey: nativeActionsMenuCacheKey,
            sections: [
                NativeToolbarMenuSection(
                    title: L10n.viewOptions,
                    items: [
                        .action(
                            id: SubscriptionActionsMenuAction.showSearch,
                            title: L10n.search,
                            systemImage: "magnifyingglass",
                            isEnabled: canShowSearch
                        ),
                        .action(
                            id: SubscriptionActionsMenuAction.clearSearch,
                            title: L10n.clearSearch,
                            systemImage: "xmark.circle",
                            isEnabled: canClearSearch
                        )
                    ]
                ),
                NativeToolbarMenuSection(
                    title: L10n.moreActions,
                    items: [
                        .action(
                            id: SubscriptionActionsMenuAction.checkUpdates,
                            title: L10n.refresh,
                            subtitle: L10n.workSubscriptionsCheckNow,
                            systemImage: "arrow.clockwise",
                            isEnabled: canCheckUpdates
                        )
                    ]
                )
            ]
        )
    }

    private var nativeActionsMenuCacheKey: String {
        [
            "subscription-actions",
            hasActiveOptions.description,
            canShowSearch.description,
            canClearSearch.description,
            canCheckUpdates.description,
            isChecking.description
        ].joined(separator: ":")
    }

    private func handleNativeAction(_ id: String) {
        switch id {
        case SubscriptionActionsMenuAction.showSearch:
            showSearch()
        case SubscriptionActionsMenuAction.clearSearch:
            clearSearch()
        case SubscriptionActionsMenuAction.checkUpdates:
            checkForUpdates()
        default:
            break
        }
    }
    #endif
}

private enum SubscriptionActionsMenuAction {
    static let showSearch = "subscription-actions:show-search"
    static let clearSearch = "subscription-actions:clear-search"
    static let checkUpdates = "subscription-actions:check-updates"
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
