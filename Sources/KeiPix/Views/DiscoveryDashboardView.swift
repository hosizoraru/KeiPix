import SwiftUI
#if os(iOS)
import UIKit
#endif

enum DiscoveryDashboardPresentation {
    case full
    case sidebarCompanion
}

struct DiscoveryDashboardView: View {
    @Bindable var store: KeiPixStore
    let presentation: DiscoveryDashboardPresentation

    init(store: KeiPixStore, presentation: DiscoveryDashboardPresentation = .full) {
        self.store = store
        self.presentation = presentation
    }

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else {
                dashboardContent
            }
        }
        .platformPageNavigationChrome(title: L10n.discover, status: navigationSubtitle)
    }

    private var navigationSubtitle: String {
        guard store.session != nil, presentation == .full else { return "" }
        return L10n.signedIn
    }

    @ViewBuilder
    private var dashboardContent: some View {
        switch presentation {
        case .full:
            fullDashboardContent
        case .sidebarCompanion:
            sidebarCompanionContent
        }
    }

    private var fullDashboardContent: some View {
        GeometryReader { proxy in
            let layout = MobileWorkspaceLayout(size: proxy.size, platform: ReaderPlatformKind.current)
            let featureStyle: DiscoveryDashboardFeatureSectionStyle = layout.usesCondensedChrome ? .compact : .full
            let routeLayout: DiscoveryDashboardRouteSectionLayout = layout.usesCustomNavigationTabs || layout.usesCondensedChrome
                ? .compactPreview
                : .regular

            ScrollView {
                GlassEffectContainer(spacing: 18) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        if featureStyle == .compact {
                            compactHeader
                        } else {
                            header
                        }

                        ForEach(store.visibleDashboardCards) { card in
                            dashboardCard(card, featureStyle: featureStyle, routeLayout: routeLayout)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private var sidebarCompanionContent: some View {
        ScrollView {
            GlassEffectContainer(spacing: 14) {
                LazyVStack(alignment: .leading, spacing: 14) {
                    compactHeader
                    DiscoveryDashboardHighlightsSection(store: store, style: .compact)
                    companionOverview
                    DiscoveryDashboardForYouSection(store: store, style: .compact)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private var header: some View {
        DiscoveryDashboardHeroCard(
            store: store,
            style: .full,
            surprise: { Task { await store.surpriseMe() } }
        )
    }

    private var compactHeader: some View {
        DiscoveryDashboardHeroCard(
            store: store,
            style: .compact,
            surprise: { Task { await store.surpriseMe() } }
        )
    }

    private var companionOverview: some View {
        DiscoveryDashboardActivitySummarySection(metrics: activityMetrics)
    }

    @ViewBuilder
    private func dashboardCard(
        _ card: DiscoveryDashboardCardKind,
        featureStyle: DiscoveryDashboardFeatureSectionStyle,
        routeLayout: DiscoveryDashboardRouteSectionLayout
    ) -> some View {
        switch card {
        case .highlights:
            DiscoveryDashboardHighlightsSection(store: store, style: featureStyle)
        case .forYou:
            DiscoveryDashboardForYouSection(store: store, style: featureStyle)
        case .tagRecommendations:
            DiscoveryDashboardTagRecommendationsSection(store: store)
        case .metrics:
            companionOverview
        case .routeGroups:
            ForEach(store.visibleDashboardSections) { section in
                DiscoveryDashboardRouteSection(section: section, store: store, layout: routeLayout)
            }
        }
    }

    private var activityMetrics: [DashboardMetric] {
        [
            DashboardMetric(id: "history", title: L10n.history, value: store.localBrowsingHistory.count.formatted(), systemImage: "clock.arrow.circlepath"),
            DashboardMetric(id: "download-total", title: L10n.downloads, value: store.downloads.items.count.formatted(), systemImage: "tray.and.arrow.down"),
            DashboardMetric(id: "download-active", title: L10n.activeDownloads, value: store.downloads.activeCount.formatted(), systemImage: "arrow.down.circle"),
            DashboardMetric(id: "saved-searches", title: L10n.savedSearches, value: store.savedSearches.count.formatted(), systemImage: "tag.circle"),
            DashboardMetric(id: "watch-later", title: L10n.watchLater, value: store.watchLaterQueue.count.formatted(), systemImage: "bookmark.circle"),
            DashboardMetric(id: "muted-content", title: L10n.mutedContent, value: store.mutedContentArchiveSnapshot().totalCount.formatted(), systemImage: "eye.slash"),
            DashboardMetric(id: "pinned-creators", title: L10n.pinnedCreators, value: store.pinnedCreatorLibrary.creators.count.formatted(), systemImage: "pin"),
            DashboardMetric(id: "work-subscriptions", title: L10n.workSubscriptions, value: store.workSubscriptions.count.formatted(), systemImage: "bell.badge")
        ]
    }

}

private enum DiscoveryDashboardHeroStyle: Equatable {
    case full
    case compact

    var cornerRadius: CGFloat {
        switch self {
        case .full:
            26
        case .compact:
            22
        }
    }

    var iconSide: CGFloat {
        switch self {
        case .full:
            52
        case .compact:
            40
        }
    }
}

private struct DiscoveryDashboardHeroCard: View {
    @Bindable var store: KeiPixStore
    let style: DiscoveryDashboardHeroStyle
    let surprise: () -> Void

    @ScaledMetric(relativeTo: .headline) private var compactAvatarSymbolSize: CGFloat = 28
    @ScaledMetric(relativeTo: .largeTitle) private var fullAvatarSymbolSize: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: style == .full ? 12 : 10) {
            HStack(alignment: .center, spacing: titleRowSpacing) {
                AccountIdentityMenuButton(
                    store: store,
                    displayStyle: .heroAvatar(
                        diameter: style.iconSide,
                        symbolSize: style == .full ? fullAvatarSymbolSize : compactAvatarSymbolSize
                    )
                )

                VStack(alignment: .leading, spacing: style == .full ? 5 : 3) {
                    if showsBoardTitle {
                        Text(L10n.discover)
                            .font(style == .full ? .title2.weight(.semibold) : .headline.weight(.semibold))
                            .lineLimit(1)
                    }

                    Text(accountSubtitle)
                        .font(accountSubtitleFont)
                        .foregroundStyle(showsBoardTitle ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showsSurpriseButton {
                    Spacer(minLength: 0)
                }
            }

            if showsSurpriseButton {
                DiscoveryDashboardHeroControlRow(
                    style: style,
                    surprise: surprise
                )
                .padding(.leading, controlRowLeadingPadding)
            }
        }
        .padding(style == .full ? 16 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(style.cornerRadius)
    }

    private var titleRowSpacing: CGFloat {
        style == .full ? 16 : 12
    }

    private var controlRowLeadingPadding: CGFloat {
        style.iconSide + titleRowSpacing
    }

    private var showsBoardTitle: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom != .phone
        #else
        true
        #endif
    }

    private var showsSurpriseButton: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom != .phone
        #else
        true
        #endif
    }

    private var accountSubtitleFont: Font {
        if showsBoardTitle {
            return style == .full ? .callout : .caption
        }
        return .headline.weight(.semibold)
    }

    private var accountSubtitle: String {
        guard let session = store.session else {
            return store.storedAccounts.isEmpty ? L10n.signedOut : L10n.realAccount
        }
        guard store.showsSidebarAccountIdentity else {
            return L10n.accountIdentityHidden
        }
        return store.accountSessionMode == .real ? "@\(session.user.account)" : store.accountSessionMode.title
    }
}

private struct DiscoveryDashboardHeroControlRow: View {
    let style: DiscoveryDashboardHeroStyle
    let surprise: () -> Void

    var body: some View {
        HStack(spacing: style == .full ? 9 : 8) {
            Button(action: surprise) {
                Label(L10n.surpriseMe, systemImage: "shuffle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(style == .full ? .regular : .small)
            .help(L10n.surpriseMe)
            .accessibilityLabel(L10n.surpriseMe)

            Spacer(minLength: 0)
        }
    }
}

private struct DashboardMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

private struct DiscoveryDashboardActivitySummarySection: View {
    let metrics: [DashboardMetric]

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 9) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .keiGlass(13)

                    Text(L10n.discoveryMetrics)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 156, maximum: 230), spacing: 8, alignment: .top)
                    ],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(metrics) { metric in
                        DashboardMetricTile(metric: metric)
                    }
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .keiGlass(20)
        }
    }
}

private struct DashboardMetricTile: View {
    let metric: DashboardMetric

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: metric.systemImage)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .keiGlass(10)

            Text(metric.title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(metric.value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(14)
    }
}

private enum DiscoveryDashboardRouteSectionLayout: Equatable {
    case regular
    case compactPreview

    var columns: [GridItem] {
        switch self {
        case .regular:
            [
                GridItem(.adaptive(minimum: 180, maximum: 270), spacing: 12, alignment: .top)
            ]
        case .compactPreview:
            [
                GridItem(.flexible(minimum: 118), spacing: 10, alignment: .top),
                GridItem(.flexible(minimum: 118), spacing: 10, alignment: .top)
            ]
        }
    }

    var sectionSpacing: CGFloat {
        switch self {
        case .regular:
            12
        case .compactPreview:
            10
        }
    }

    var cardSpacing: CGFloat {
        switch self {
        case .regular:
            12
        case .compactPreview:
            10
        }
    }

    var sectionPadding: CGFloat {
        switch self {
        case .regular:
            14
        case .compactPreview:
            12
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .regular:
            22
        case .compactPreview:
            20
        }
    }
}

private struct DiscoveryDashboardRouteSection: View {
    let section: DiscoveryDashboardSection
    @Bindable var store: KeiPixStore
    let layout: DiscoveryDashboardRouteSectionLayout

    var body: some View {
        let preview = routePreview

        GlassEffectContainer(spacing: layout.sectionSpacing) {
            VStack(alignment: .leading, spacing: layout.sectionSpacing) {
                DiscoveryDashboardSectionHeader(
                    title: section.title,
                    systemImage: section.systemImage,
                    count: section.routes.count,
                    isExpanded: store.isDashboardRouteSectionExpanded(section),
                    isExpandable: layout == .compactPreview && section.routes.count > DiscoveryDashboardRoutePreview.compactRouteLimit,
                    isTruncated: preview.isTruncated
                ) {
                    store.setDashboardRouteSectionExpanded(
                        store.isDashboardRouteSectionExpanded(section) == false,
                        for: section
                    )
                }

                LazyVGrid(columns: layout.columns, alignment: .leading, spacing: layout.cardSpacing) {
                    ForEach(preview.routes) { route in
                        DiscoveryDashboardRouteCard(
                            route: route,
                            metric: metric(for: route),
                            isSelected: store.selectedRoute == route,
                            layout: layout
                        ) {
                            store.select(route)
                        }
                    }
                }
                .animation(.snappy(duration: 0.22), value: preview.routes)

                if isExpandable {
                    Button {
                        store.setDashboardRouteSectionExpanded(
                            store.isDashboardRouteSectionExpanded(section) == false,
                            for: section
                        )
                    } label: {
                        Label(
                            store.isDashboardRouteSectionExpanded(section) ? L10n.showLess : L10n.showMore,
                            systemImage: store.isDashboardRouteSectionExpanded(section) ? "chevron.up" : "chevron.down"
                        )
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .accessibilityLabel(store.isDashboardRouteSectionExpanded(section) ? L10n.showLess : L10n.showMore)
                }
            }
            .padding(layout.sectionPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keiGlass(layout.cornerRadius)
        }
    }

    private var routePreview: DiscoveryDashboardRoutePreview {
        if layout == .compactPreview {
            DiscoveryDashboardRoutePreview(
                section: section,
                isExpanded: store.isDashboardRouteSectionExpanded(section),
                selectedRoute: store.selectedRoute
            )
        } else {
            DiscoveryDashboardRoutePreview(
                section: section,
                isExpanded: true,
                selectedRoute: store.selectedRoute
            )
        }
    }

    private var isExpandable: Bool {
        layout == .compactPreview && section.routes.count > DiscoveryDashboardRoutePreview.compactRouteLimit
    }

    private func metric(for route: PixivRoute) -> String? {
        switch route {
        case .savedSearches:
            return store.savedSearches.isEmpty ? nil : store.savedSearches.count.formatted()
        case .history:
            return store.localBrowsingHistory.isEmpty ? nil : store.localBrowsingHistory.count.formatted()
        case .pinnedCreators:
            return store.pinnedCreatorLibrary.creators.isEmpty ? nil : store.pinnedCreatorLibrary.creators.count.formatted()
        case .mangaWatchlist:
            return store.mangaWatchlistReadStateLibrary.items.isEmpty ? nil : store.mangaWatchlistReadStateLibrary.items.count.formatted()
        case .downloads:
            return store.downloads.items.isEmpty ? nil : store.downloads.items.count.formatted()
        case .spotlight:
            let count = store.spotlightFavoriteArticles.count + store.spotlightArticleHistory.count
            return count == 0 ? nil : count.formatted()
        default:
            return nil
        }
    }
}

private struct DiscoveryDashboardSectionHeader: View {
    let title: String
    let systemImage: String
    let count: Int
    let isExpanded: Bool
    let isExpandable: Bool
    let isTruncated: Bool
    let toggleExpansion: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 32, height: 32)
                .keiGlass(14)

            Text(title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 0)

            Text(count.formatted())
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .glassEffect(.regular, in: Capsule(style: .continuous))

            if isExpandable {
                Button(action: toggleExpansion) {
                    Label(isExpanded ? L10n.showLess : L10n.showMore, systemImage: isExpanded ? "chevron.up" : "chevron.down")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .help(isExpanded ? L10n.showLess : L10n.showMore)
                .accessibilityLabel(isExpanded ? L10n.showLess : L10n.showMore)
                .accessibilityHint(isTruncated ? L10n.showMore : L10n.showLess)
            }
        }
    }
}

private struct DiscoveryDashboardRouteCard: View {
    let route: PixivRoute
    let metric: String?
    let isSelected: Bool
    let layout: DiscoveryDashboardRouteSectionLayout
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: layout == .compactPreview ? 8 : 10) {
                Image(systemName: route.systemImage)
                    .font(.system(size: layout == .compactPreview ? 16 : 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: layout == .compactPreview ? 30 : 34, height: layout == .compactPreview ? 30 : 34)
                    .keiGlass(layout == .compactPreview ? 12 : 14)

                VStack(alignment: .leading, spacing: layout == .compactPreview ? 4 : 6) {
                    Text(route.title)
                        .font(layout == .compactPreview ? .caption.weight(.semibold) : .callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    if let metric {
                        Text(metric)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .glassEffect(.regular, in: Capsule(style: .continuous))
                    }
                }

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.tint)
                }
            }
            .padding(layout == .compactPreview ? 10 : 12)
            .frame(maxWidth: .infinity, minHeight: layout == .compactPreview ? 66 : 82, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: layout == .compactPreview ? 16 : 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(layout == .compactPreview ? 16 : 18)
        .overlay {
            RoundedRectangle(cornerRadius: layout == .compactPreview ? 16 : 18, style: .continuous)
                .strokeBorder(strokeStyle, lineWidth: isSelected ? 1.2 : 0.8)
        }
        .shadow(color: .black.opacity(isHovering ? 0.10 : 0), radius: isHovering ? 12 : 0, y: isHovering ? 7 : 0)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .animation(.snappy(duration: 0.16), value: isSelected)
        .keiPixHoverTracker { isHovering = $0 }
        .help(route.title)
    }

    private var strokeStyle: Color {
        isSelected ? Color.accentColor.opacity(0.48) : Color.secondary.opacity(isHovering ? 0.18 : 0.08)
    }
}

struct DashboardCustomizationSheet: View {
    @Bindable var store: KeiPixStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.dashboardCards) {
                    ForEach(store.dashboardCardOrder) { card in
                        DashboardCustomizationCardRow(
                            card: card,
                            isVisible: Binding(
                                get: { store.isDashboardCardVisible(card) },
                                set: { store.setDashboardCardVisible($0, for: card) }
                            ),
                            canMoveUp: store.dashboardCardOrder.first != card,
                            canMoveDown: store.dashboardCardOrder.last != card,
                            moveUp: {
                                withAnimation(.snappy(duration: 0.18)) {
                                    store.moveDashboardCard(card, offset: -1)
                                }
                            },
                            moveDown: {
                                withAnimation(.snappy(duration: 0.18)) {
                                    store.moveDashboardCard(card, offset: 1)
                                }
                            }
                        )
                    }
                }

                Section(L10n.dashboardSections) {
                    ForEach(DiscoveryDashboardSection.all) { section in
                        HStack {
                            Image(systemName: section.systemImage)
                                .foregroundStyle(.secondary)
                                .frame(width: 24)

                            Text(section.title)

                            Spacer()

                            Text("\(section.routes.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)

                            Toggle("", isOn: Binding(
                                get: { store.isDashboardSectionVisible(section) },
                                set: { store.setDashboardSectionVisible($0, for: section) }
                            ))
                            .labelsHidden()
                        }
                    }
                }

                Section {
                    Button(L10n.resetDashboardSections) {
                        store.resetDashboardSections()
                    }
                    .foregroundStyle(.secondary)
                }
            }
            #if os(macOS)
            .frame(minWidth: 360, minHeight: 400)
            #endif
            .navigationTitle(L10n.customizeDashboard)
            .animation(.snappy(duration: 0.18), value: store.dashboardCardOrderID)
            .animation(.snappy(duration: 0.18), value: store.hiddenDashboardCardIDs)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }
}

private struct DashboardCustomizationCardRow: View {
    let card: DiscoveryDashboardCardKind
    @Binding var isVisible: Bool
    let canMoveUp: Bool
    let canMoveDown: Bool
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label(card.title, systemImage: card.systemImage)
                .lineLimit(1)

            Spacer(minLength: 8)

            Menu {
                Button(action: moveUp) {
                    Label(L10n.moveUp, systemImage: "chevron.up")
                }
                .disabled(canMoveUp == false)

                Button(action: moveDown) {
                    Label(L10n.moveDown, systemImage: "chevron.down")
                }
                .disabled(canMoveDown == false)
            } label: {
                Label(L10n.reorder, systemImage: "arrow.up.arrow.down")
                    .labelStyle(.iconOnly)
            }
            .menuStyle(.button)
            .help(L10n.reorder)
            .accessibilityLabel(L10n.reorder)

            Toggle("", isOn: $isVisible)
                .labelsHidden()
                .accessibilityLabel(card.title)
        }
    }
}
