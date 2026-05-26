import SwiftUI

struct DiscoveryDashboardView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Group {
            if store.session == nil {
                signedOutContent
            } else {
                dashboardContent
            }
        }
        .navigationTitle(L10n.discover)
        .navigationSubtitle(store.session != nil ? L10n.signedIn : "")
    }

    private var dashboardContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header

                ForEach(DiscoveryDashboardSection.all) { section in
                    DiscoveryDashboardRouteSection(section: section, store: store)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 28, weight: .semibold))
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
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }

    private var signedOutContent: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 56, weight: .medium))
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
        .onHover { isHovering = $0 }
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
