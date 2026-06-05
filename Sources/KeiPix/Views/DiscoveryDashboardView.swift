import SwiftUI

enum DiscoveryDashboardPresentation {
    case full
    case sidebarCompanion
}

struct DiscoveryDashboardView: View {
    @Bindable var store: KeiPixStore
    let presentation: DiscoveryDashboardPresentation
    @State private var isCustomizationPresented = false

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
        .sheet(isPresented: $isCustomizationPresented) {
            DashboardCustomizationSheet(store: store)
                .os26SheetChrome(.form)
        }
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
        ScrollView {
            GlassEffectContainer(spacing: 18) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    header

                    DiscoveryDashboardHighlightsSection(store: store, style: .full)
                    DiscoveryDashboardForYouSection(store: store, style: .full)

                    ForEach(store.visibleDashboardSections) { section in
                        DiscoveryDashboardRouteSection(section: section, store: store)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
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
            surprise: { Task { await store.surpriseMe() } },
            customize: { isCustomizationPresented = true }
        )
    }

    private var compactHeader: some View {
        DiscoveryDashboardHeroCard(
            store: store,
            style: .compact,
            surprise: { Task { await store.surpriseMe() } },
            customize: { isCustomizationPresented = true }
        )
    }

    private var companionOverview: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                companionPrimaryColumn
                    .frame(minWidth: 260, maxWidth: .infinity, alignment: .topLeading)
                companionSecondaryColumn
                    .frame(minWidth: 260, maxWidth: .infinity, alignment: .topLeading)
            }

            VStack(alignment: .leading, spacing: 14) {
                companionPrimaryColumn
                companionSecondaryColumn
            }
        }
    }

    private var companionPrimaryColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardMetricGroupCard(title: L10n.works, systemImage: "photo.stack", metrics: workMetrics)
            DashboardMetricGroupCard(title: L10n.downloads, systemImage: "arrow.down.circle", metrics: downloadMetrics)
        }
    }

    private var companionSecondaryColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            DashboardMetricGroupCard(title: L10n.library, systemImage: "books.vertical", metrics: libraryMetrics)
            DashboardMetricGroupCard(title: L10n.creatorNetwork, systemImage: "person.2.crop.square.stack", metrics: creatorMetrics)
        }
    }

    private var workMetrics: [DashboardMetric] {
        [
            DashboardMetric(id: "feed", title: L10n.feed, value: store.artworks.count.formatted(), systemImage: "photo.on.rectangle"),
            DashboardMetric(id: "manga-watchlist", title: L10n.mangaWatchlist, value: store.mangaWatchlistReadStateLibrary.items.count.formatted(), systemImage: "book.closed"),
            DashboardMetric(id: "novel-watchlist", title: L10n.novelWatchlist, value: store.novels.watchlistSeries.count.formatted(), systemImage: "books.vertical")
        ]
    }

    private var libraryMetrics: [DashboardMetric] {
        [
            DashboardMetric(id: "saved-searches", title: L10n.savedSearches, value: store.savedSearches.count.formatted(), systemImage: "tag.circle"),
            DashboardMetric(id: "history", title: L10n.history, value: store.localBrowsingHistory.count.formatted(), systemImage: "clock.arrow.circlepath"),
            DashboardMetric(id: "watch-later", title: L10n.watchLater, value: store.watchLaterQueue.count.formatted(), systemImage: "bookmark.circle"),
            DashboardMetric(id: "muted-content", title: L10n.mutedContent, value: store.mutedContentArchiveSnapshot().totalCount.formatted(), systemImage: "eye.slash")
        ]
    }

    private var downloadMetrics: [DashboardMetric] {
        [
            DashboardMetric(id: "download-total", title: L10n.downloads, value: store.downloads.items.count.formatted(), systemImage: "tray.and.arrow.down"),
            DashboardMetric(id: "download-active", title: L10n.activeDownloads, value: store.downloads.activeCount.formatted(), systemImage: "arrow.down.circle"),
            DashboardMetric(id: "download-completed", title: L10n.completedDownloads, value: store.downloads.completedCount.formatted(), systemImage: "checkmark.circle")
        ]
    }

    private var creatorMetrics: [DashboardMetric] {
        [
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
    let customize: () -> Void

    @ScaledMetric(relativeTo: .headline) private var compactIconSize: CGFloat = 20
    @ScaledMetric(relativeTo: .largeTitle) private var fullIconSize: CGFloat = 30

    var body: some View {
        HStack(alignment: .center, spacing: style == .full ? 16 : 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: style == .full ? fullIconSize : compactIconSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: style.iconSide, height: style.iconSide)
                .keiGlass(style == .full ? 20 : 16)

            VStack(alignment: .leading, spacing: style == .full ? 8 : 5) {
                Text(L10n.discover)
                    .font(style == .full ? .title2.weight(.semibold) : .headline.weight(.semibold))
                    .lineLimit(1)

                FlowLayout(spacing: 7) {
                    DashboardStatusPill(title: L10n.currentRoute, value: store.selectedRoute.title, systemImage: "location")
                    if style == .full {
                        DashboardStatusPill(title: L10n.feed, value: store.artworks.count.formatted(), systemImage: "photo.on.rectangle")
                        DashboardStatusPill(title: L10n.downloads, value: store.downloads.items.count.formatted(), systemImage: "arrow.down.circle")
                    } else {
                        DashboardStatusPill(title: L10n.session, value: L10n.signedIn, systemImage: "person.crop.circle.badge.checkmark")
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            heroActions
        }
        .padding(style == .full ? 16 : 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(style.cornerRadius)
    }

    private var heroActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 9) {
                surpriseButton(showsTitle: style == .full)
                customizeButton(showsTitle: style == .full)
            }

            HStack(spacing: 8) {
                surpriseButton(showsTitle: false)
                customizeButton(showsTitle: false)
            }
        }
    }

    @ViewBuilder
    private func surpriseButton(showsTitle: Bool) -> some View {
        if showsTitle {
            Button(action: surprise) {
                Label(L10n.surpriseMe, systemImage: "shuffle")
                    .lineLimit(1)
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(style == .full ? .regular : .small)
            .help(L10n.surpriseMe)
            .accessibilityLabel(L10n.surpriseMe)
        } else {
            Button(action: surprise) {
                Label(L10n.surpriseMe, systemImage: "shuffle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.capsule)
            .controlSize(style == .full ? .regular : .small)
            .help(L10n.surpriseMe)
            .accessibilityLabel(L10n.surpriseMe)
        }
    }

    @ViewBuilder
    private func customizeButton(showsTitle: Bool) -> some View {
        if showsTitle {
            Button(action: customize) {
                Label(L10n.customizeDashboard, systemImage: "slider.horizontal.3")
                    .lineLimit(1)
            }
            .labelStyle(.titleAndIcon)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(style == .full ? .regular : .small)
            .help(L10n.customizeDashboard)
            .accessibilityLabel(L10n.customizeDashboard)
        } else {
            Button(action: customize) {
                Label(L10n.customizeDashboard, systemImage: "slider.horizontal.3")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(style == .full ? .regular : .small)
            .help(L10n.customizeDashboard)
            .accessibilityLabel(L10n.customizeDashboard)
        }
    }
}

private struct DashboardMetric: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

private struct DashboardMetricGroupCard: View {
    let title: String
    let systemImage: String
    let metrics: [DashboardMetric]

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 9) {
                    Image(systemName: systemImage)
                        .font(.subheadline.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .keiGlass(13)

                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(metrics) { metric in
                        DashboardMetricTile(metric: metric)
                    }
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
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

private struct DiscoveryDashboardRouteSection: View {
    let section: DiscoveryDashboardSection
    @Bindable var store: KeiPixStore

    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 270), spacing: 12, alignment: .top)
    ]

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                DiscoveryDashboardSectionHeader(
                    title: section.title,
                    systemImage: section.systemImage,
                    count: section.routes.count
                )

                LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                    ForEach(section.routes) { route in
                        DiscoveryDashboardRouteCard(
                            route: route,
                            metric: metric(for: route),
                            isSelected: store.selectedRoute == route
                        ) {
                            store.select(route)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keiGlass(22)
        }
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
        }
    }
}

private struct DiscoveryDashboardRouteCard: View {
    let route: PixivRoute
    let metric: String?
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: route.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 34, height: 34)
                    .keiGlass(14)

                VStack(alignment: .leading, spacing: 6) {
                    Text(route.title)
                        .font(.callout.weight(.semibold))
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
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(18)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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

private struct DashboardStatusPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            Text("\(title): \(value)")
                .lineLimit(1)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular, in: Capsule(style: .continuous))
    }
}

private struct DashboardCustomizationSheet: View {
    @Bindable var store: KeiPixStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
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
                        store.hiddenDashboardSectionIDs.removeAll()
                        UserDefaults.standard.removeObject(forKey: "hiddenDashboardSectionIDs")
                    }
                    .foregroundStyle(.secondary)
                }
            }
            #if os(macOS)
            .frame(minWidth: 360, minHeight: 400)
            #endif
            .navigationTitle(L10n.customizeDashboard)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }
}
