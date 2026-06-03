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
                signedOutContent
            } else {
                dashboardContent
            }
        }
        .navigationTitle(L10n.discover)
        .navigationSubtitle(navigationSubtitle)
        .sheet(isPresented: $isCustomizationPresented) {
            DashboardCustomizationSheet(store: store)
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
            LazyVStack(alignment: .leading, spacing: 18) {
                header

                DiscoveryTrendingTagsStrip(store: store)

                ForEach(store.visibleDashboardSections) { section in
                    DiscoveryDashboardRouteSection(section: section, store: store)
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
            LazyVStack(alignment: .leading, spacing: 14) {
                compactHeader
                companionOverview
                DiscoveryTrendingTagsStrip(store: store)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 18)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    @ScaledMetric(relativeTo: .headline) private var headerIconSize: CGFloat = 28

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: headerIconSize, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.discover)
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    DashboardStatusPill(title: L10n.currentRoute, value: store.selectedRoute.title, systemImage: "location")
                    DashboardStatusPill(title: L10n.feed, value: "\(store.artworks.count.formatted())", systemImage: "photo.on.rectangle")
                    DashboardStatusPill(title: L10n.downloads, value: "\(store.downloads.items.count.formatted())", systemImage: "arrow.down.circle")
                }
            }

            Spacer(minLength: 0)

            Button {
                Task { await store.surpriseMe() }
            } label: {
                Label(L10n.surpriseMe, systemImage: "shuffle")
            }
            .labelStyle(.iconOnly)
            .help(L10n.surpriseMe)
            .accessibilityLabel(L10n.surpriseMe)

            Button {
                isCustomizationPresented = true
            } label: {
                Label(L10n.customizeDashboard, systemImage: "slider.horizontal.3")
            }
            .labelStyle(.iconOnly)
            .help(L10n.customizeDashboard)
            .accessibilityLabel(L10n.customizeDashboard)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }

    private var compactHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 20, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.discover)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)

                Text(L10n.signedIn)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button {
                Task { await store.surpriseMe() }
            } label: {
                Label(L10n.surpriseMe, systemImage: "shuffle")
            }
            .labelStyle(.iconOnly)
            .help(L10n.surpriseMe)
            .accessibilityLabel(L10n.surpriseMe)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
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

    @ScaledMetric(relativeTo: .largeTitle) private var signedOutIconSize: CGFloat = 56

    private var signedOutContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: signedOutIconSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                Text(L10n.signedOutTitle)
                    .font(.title2.weight(.semibold))
                Text(L10n.signedOutSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 480)
            }

            Button {
                store.isLoginPresented = true
            } label: {
                Label(L10n.login, systemImage: "person.crop.circle.badge.plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(metrics) { metric in
                    DashboardMetricTile(metric: metric)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 156, alignment: .topLeading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
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
                .frame(width: 18)

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
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DiscoveryDashboardRouteSection: View {
    let section: DiscoveryDashboardSection
    @Bindable var store: KeiPixStore

    private let columns = [
        GridItem(.adaptive(minimum: 168, maximum: 260), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(section.title, systemImage: section.systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

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
                    .frame(width: 28, height: 28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

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
                            .background(.quaternary, in: Capsule())
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(backgroundStyle, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(strokeStyle, lineWidth: isSelected ? 1.4 : 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.10 : 0), radius: isHovering ? 10 : 0, y: isHovering ? 6 : 0)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .animation(.snappy(duration: 0.16), value: isSelected)
        .keiPixHoverTracker { isHovering = $0 }
        .help(route.title)
    }

    private var backgroundStyle: some ShapeStyle {
        isSelected || isHovering ? AnyShapeStyle(.regularMaterial) : AnyShapeStyle(.thinMaterial)
    }

    private var strokeStyle: Color {
        isSelected ? Color.accentColor.opacity(0.55) : Color.secondary.opacity(isHovering ? 0.22 : 0.12)
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
        .background(.regularMaterial, in: Capsule())
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
