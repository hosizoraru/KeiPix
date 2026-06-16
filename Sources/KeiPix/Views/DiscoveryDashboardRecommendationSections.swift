import SwiftUI

enum DiscoveryDashboardFeatureSectionStyle: Equatable {
    case full
    case compact

    var sectionPadding: CGFloat {
        switch self {
        case .full:
            14
        case .compact:
            12
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .full:
            22
        case .compact:
            20
        }
    }

    var highlightCardWidth: CGFloat {
        switch self {
        case .full:
            286
        case .compact:
            224
        }
    }

    var highlightCardHeight: CGFloat {
        switch self {
        case .full:
            136
        case .compact:
            118
        }
    }

    var recommendationColumns: [GridItem] {
        switch self {
        case .full:
            [
                GridItem(.adaptive(minimum: 172, maximum: 240), spacing: 10, alignment: .top)
            ]
        case .compact:
            [
                GridItem(.flexible(minimum: 118), spacing: 10, alignment: .top),
                GridItem(.flexible(minimum: 118), spacing: 10, alignment: .top)
            ]
        }
    }
}

private struct DiscoveryDashboardFeature: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImage: String
    let route: PixivRoute
    let accent: Color

    init(
        route: PixivRoute,
        title: String? = nil,
        subtitle: String,
        systemImage: String? = nil,
        accent: Color
    ) {
        self.id = route.rawValue
        self.title = title ?? route.title
        self.subtitle = subtitle
        self.systemImage = systemImage ?? route.systemImage
        self.route = route
        self.accent = accent
    }
}

struct DiscoveryDashboardHighlightsSection: View {
    @Bindable var store: KeiPixStore
    let style: DiscoveryDashboardFeatureSectionStyle

    private var features: [DiscoveryDashboardFeature] {
        [
            DiscoveryDashboardFeature(
                route: .spotlight,
                title: L10n.spotlight,
                subtitle: L10n.recommendedArticles,
                systemImage: "newspaper",
                accent: .pink
            ),
            DiscoveryDashboardFeature(
                route: .rankingDaily,
                title: L10n.ranking,
                subtitle: L10n.daily,
                systemImage: "chart.bar",
                accent: .orange
            ),
            DiscoveryDashboardFeature(
                route: .newIllustrations,
                title: L10n.newIllustrations,
                subtitle: L10n.works,
                systemImage: "sparkle.magnifyingglass",
                accent: .cyan
            )
        ]
    }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                DiscoveryDashboardFeatureSectionHeader(
                    title: L10n.discoveryHighlights,
                    systemImage: "sparkles.rectangle.stack",
                    actionTitle: L10n.viewAll
                ) {
                    store.select(.spotlight)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(features) { feature in
                            DiscoveryDashboardHighlightCard(
                                feature: feature,
                                style: style,
                                isSelected: store.selectedRoute == feature.route
                            ) {
                                store.select(feature.route)
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                    .padding(.bottom, 1)
                }
            }
            .padding(style.sectionPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keiGlass(style.cornerRadius)
        }
    }
}

struct DiscoveryDashboardForYouSection: View {
    @Bindable var store: KeiPixStore
    let style: DiscoveryDashboardFeatureSectionStyle

    private var features: [DiscoveryDashboardFeature] {
        [
            DiscoveryDashboardFeature(
                route: .pixivCollections,
                title: L10n.pixivCollections,
                subtitle: L10n.discover,
                systemImage: "rectangle.stack.badge.person.crop",
                accent: .blue
            ),
            DiscoveryDashboardFeature(
                route: .trendingTags,
                title: L10n.trendingTags,
                subtitle: L10n.explore,
                systemImage: "number",
                accent: .purple
            ),
            DiscoveryDashboardFeature(
                route: .recommendedUsers,
                title: L10n.recommendedCreators,
                subtitle: L10n.creatorNetwork,
                systemImage: "person.crop.circle.badge.plus",
                accent: .indigo
            ),
            DiscoveryDashboardFeature(
                route: .novelRecommended,
                title: L10n.recommendedNovels,
                subtitle: L10n.novels,
                systemImage: "book",
                accent: .teal
            )
        ]
    }

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                DiscoveryDashboardFeatureSectionHeader(
                    title: L10n.discoveryForYou,
                    systemImage: "person.crop.circle.badge.sparkles"
                )

                LazyVGrid(columns: style.recommendationColumns, alignment: .leading, spacing: 10) {
                    ForEach(features) { feature in
                        DiscoveryDashboardForYouCard(
                            feature: feature,
                            style: style,
                            isSelected: store.selectedRoute == feature.route
                        ) {
                            store.select(feature.route)
                        }
                    }
                }
            }
            .padding(style.sectionPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keiGlass(style.cornerRadius)
        }
    }
}

private struct DiscoveryDashboardFeatureSectionHeader: View {
    let title: String
    let systemImage: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 0)

            if let actionTitle, let action {
                Button(action: action) {
                    Label(actionTitle, systemImage: "chevron.right")
                        .labelStyle(.titleAndIcon)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
            }
        }
    }
}

private struct DiscoveryDashboardHighlightCard: View {
    let feature: DiscoveryDashboardFeature
    let style: DiscoveryDashboardFeatureSectionStyle
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                cardBackground

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: feature.systemImage)
                            .font(.title3.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(feature.accent)
                            .frame(width: 42, height: 42)
                            .keiGlass(16)

                        Spacer(minLength: 0)

                        Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right.circle")
                            .font(.title3.weight(.semibold))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    }

                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(feature.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(feature.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(14)
            }
            .frame(width: style.highlightCardWidth, height: style.highlightCardHeight, alignment: .leading)
            .clipShape(cardShape)
            .containerShape(cardShape)
            .contentShape(cardShape)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: cardShape)
        .overlay {
            cardShape
                .strokeBorder(strokeStyle, lineWidth: isSelected ? 1.2 : 0.8)
        }
        .animation(.snappy(duration: 0.16), value: isHovering)
        .animation(.snappy(duration: 0.16), value: isSelected)
        .keiPixHoverTracker { isHovering = $0 }
        .help(feature.title)
        .accessibilityLabel("\(feature.title), \(feature.subtitle)")
    }

    private var cardShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
    }

    private var cardBackground: some View {
        cardShape
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: feature.accent.opacity(isHovering ? 0.20 : 0.14), location: 0),
                        .init(color: Color.accentColor.opacity(isHovering ? 0.10 : 0.06), location: 0.58),
                        .init(color: Color.primary.opacity(0.02), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(alignment: .topTrailing) {
                cardShape
                    .fill(
                        RadialGradient(
                            colors: [
                                feature.accent.opacity(isHovering ? 0.20 : 0.12),
                                .clear
                            ],
                            center: .topTrailing,
                            startRadius: 0,
                            endRadius: 145
                        )
                    )
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(false)
    }

    private var strokeStyle: Color {
        isSelected ? Color.accentColor.opacity(0.48) : Color.secondary.opacity(isHovering ? 0.18 : 0.08)
    }
}

private struct DiscoveryDashboardForYouCard: View {
    let feature: DiscoveryDashboardFeature
    let style: DiscoveryDashboardFeatureSectionStyle
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: style == .full ? 12 : 10) {
                Image(systemName: feature.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? Color.accentColor : feature.accent)
                    .frame(width: 34, height: 34, alignment: .center)
                    .keiGlass(14)

                VStack(alignment: .leading, spacing: 3) {
                    Text(feature.title)
                        .font(style == .full ? .callout.weight(.semibold) : .caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(feature.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: style == .full ? 116 : 104, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(18)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(strokeStyle, lineWidth: isSelected ? 1.1 : 0.8)
        }
        .animation(.snappy(duration: 0.16), value: isHovering)
        .animation(.snappy(duration: 0.16), value: isSelected)
        .keiPixHoverTracker { isHovering = $0 }
        .help(feature.title)
        .accessibilityLabel("\(feature.title), \(feature.subtitle)")
    }

    private var strokeStyle: Color {
        isSelected ? Color.accentColor.opacity(0.42) : Color.secondary.opacity(isHovering ? 0.16 : 0.07)
    }
}
