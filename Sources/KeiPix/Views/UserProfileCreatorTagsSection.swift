import SwiftUI

struct UserProfileCreatorTagsSection: View {
    let user: PixivUser
    @Bindable var store: KeiPixStore
    let openTag: (CreatorArtworkTag) -> Void
    var visualQAArtworks: [PixivArtwork]? = nil

    @State private var tags: [CreatorArtworkTag] = []
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let collapsedCap = 18
    private let expandedCap = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerAndSearch

            if isLoading {
                loadingRow
            } else if visibleTags.isEmpty {
                emptyState
            } else {
                tagCloud
            }
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .task(id: user.id) {
            await loadTags()
        }
    }

    private var headerAndSearch: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                titleCluster

                Spacer(minLength: 12)

                searchField
                    .frame(maxWidth: 420)

                retryButton
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    titleCluster
                    Spacer(minLength: 0)
                    retryButton
                }
                searchField
            }
        }
    }

    private var titleCluster: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label(L10n.creatorTags, systemImage: "number")
                .font(.headline)

            if tags.isEmpty == false {
                Text("\(tags.count.formatted())")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .glassEffect(.regular, in: Capsule(style: .continuous))
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            NativeSearchField(
                text: $query,
                placeholder: L10n.searchCreatorTags,
                suggestions: [],
                onSubmit: {},
                onTextChange: { query = $0 }
            )
            .frame(minWidth: 180, maxWidth: .infinity)

            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button {
                    query = ""
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle.fill")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .help(L10n.clearSearch)
            }
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var retryButton: some View {
        if errorMessage != nil {
            Button {
                Task { await loadTags() }
            } label: {
                Label(L10n.retry, systemImage: "arrow.clockwise")
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
        }
    }

    private var loadingRow: some View {
        OS26InlineLoadingView(title: L10n.loading, systemImage: "number", minHeight: 120)
    }

    @ViewBuilder
    private var emptyState: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.callout)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if tags.isEmpty {
            OS26InlineUnavailableView(
                title: L10n.noCreatorTags,
                systemImage: "number",
                minHeight: 120
            )
        } else {
            OS26InlineUnavailableView(
                title: L10n.noMatchingCreatorTags,
                systemImage: "line.3.horizontal.decrease.circle",
                minHeight: 120
            )
        }
    }

    private var tagCloud: some View {
        GlassEffectContainer(spacing: 8) {
            FlowLayout(spacing: 8) {
                ForEach(visibleTags) { tag in
                    CreatorArtworkTagChip(tag: tag) {
                        openTag(tag)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var visibleTags: [CreatorArtworkTag] {
        let filtered = tags.filter { $0.matches(query) }
        return Array(filtered.prefix(query.trimmedNonEmpty == nil ? collapsedCap : expandedCap))
    }

    private func loadTags() async {
        if let visualQAArtworks {
            tags = Self.tags(from: visualQAArtworks)
            errorMessage = nil
            isLoading = false
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            tags = try await store.creatorIllustTags(for: user)
        } catch {
            tags = []
            errorMessage = error.localizedDescription
        }
    }

    private static func tags(from artworks: [PixivArtwork]) -> [CreatorArtworkTag] {
        var counts: [String: (tag: PixivTag, count: Int)] = [:]
        for artwork in artworks where artwork.type == "illust" {
            for tag in artwork.tags {
                let normalized = tag.name.trimmingCharacters(in: .whitespacesAndNewlines)
                guard normalized.isEmpty == false else { continue }
                if var existing = counts[normalized] {
                    existing.count += 1
                    counts[normalized] = existing
                } else {
                    counts[normalized] = (tag, 1)
                }
            }
        }

        return counts.values
            .map { value in
                CreatorArtworkTag(
                    name: value.tag.name,
                    translatedName: value.tag.translatedName,
                    yomigana: nil,
                    count: value.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
    }
}

private struct CreatorArtworkTagChip: View {
    let tag: CreatorArtworkTag
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("# \(tag.name)")
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if let subtitle = tag.displaySubtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .layoutPriority(1)

                Text(tag.count.formatted())
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .glassEffect(.regular, in: Capsule(style: .continuous))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, tag.displaySubtitle == nil ? 8 : 7)
            .frame(minWidth: 150, maxWidth: 218, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .help("# \(tag.name)")
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        if let subtitle = tag.displaySubtitle {
            return "# \(tag.name), \(subtitle), \(tag.count.formatted())"
        }
        return "# \(tag.name), \(tag.count.formatted())"
    }
}
