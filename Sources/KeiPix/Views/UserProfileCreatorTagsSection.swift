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
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let collapsedCap = 18
    private let expandedCap = 60

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 12) {
            headerAndSearch

            if isLoading {
                loadingRow
            } else if visibleTags.isEmpty {
                emptyState
            } else {
                tagCloud
            }
        }
        .padding(isCompact ? 12 : 14)
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
            NativeSearchField(
                text: $query,
                placeholder: L10n.searchCreatorTags,
                suggestions: [],
                onSubmit: {},
                onTextChange: { query = $0 }
            )
            .frame(minWidth: isCompact ? 120 : 180, maxWidth: .infinity)

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
            if isCompact {
                CreatorArtworkTagTwoColumnLayout(spacing: 8) {
                    ForEach(visibleTags) { tag in
                        CreatorArtworkTagChip(tag: tag, fillsAvailableWidth: true) {
                            openTag(tag)
                        }
                        .layoutValue(key: CreatorArtworkTagFullWidthKey.self, value: tag.prefersFullWidthChip)
                    }
                }
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(visibleTags) { tag in
                        CreatorArtworkTagChip(tag: tag, fillsAvailableWidth: false) {
                            openTag(tag)
                        }
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

    private var isCompact: Bool {
        horizontalSizeClass == .compact
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

private struct CreatorArtworkTagFullWidthKey: LayoutValueKey {
    static let defaultValue = false
}

private struct CreatorArtworkTagTwoColumnLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        return resolvedLayout(in: width, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for item in resolvedLayout(in: bounds.width, subviews: subviews).items {
            subviews[item.index].place(
                at: CGPoint(x: bounds.minX + item.frame.minX, y: bounds.minY + item.frame.minY),
                proposal: ProposedViewSize(item.frame.size)
            )
        }
    }

    private func resolvedLayout(in width: CGFloat, subviews: Subviews) -> (items: [(index: Int, frame: CGRect)], size: CGSize) {
        let availableWidth = max(width, 1)
        let columnWidth = max((availableWidth - spacing) / 2, 1)
        var items: [(index: Int, frame: CGRect)] = []
        var y: CGFloat = 0
        var halfRow: [(index: Int, size: CGSize)] = []

        func appendHalfRow() {
            guard halfRow.isEmpty == false else { return }
            let rowHeight = halfRow.map(\.size.height).max() ?? 0
            for (offset, item) in halfRow.enumerated() {
                let x = offset == 0 ? CGFloat(0) : columnWidth + spacing
                items.append((
                    item.index,
                    CGRect(x: x, y: y, width: columnWidth, height: rowHeight)
                ))
            }
            y += rowHeight + spacing
            halfRow.removeAll()
        }

        for (index, subview) in subviews.enumerated() {
            if subview[CreatorArtworkTagFullWidthKey.self] {
                appendHalfRow()
                let size = subview.sizeThatFits(ProposedViewSize(width: availableWidth, height: nil))
                items.append((
                    index,
                    CGRect(x: 0, y: y, width: availableWidth, height: size.height)
                ))
                y += size.height + spacing
            } else {
                let size = subview.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil))
                halfRow.append((index, size))
                if halfRow.count == 2 {
                    appendHalfRow()
                }
            }
        }

        appendHalfRow()
        if y > 0 {
            y -= spacing
        }
        return (items, CGSize(width: availableWidth, height: max(y, 0)))
    }
}

private struct CreatorArtworkTagChip: View {
    let tag: CreatorArtworkTag
    let fillsAvailableWidth: Bool
    let action: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: isCompact ? 6 : 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("# \(tag.name)")
                        .font(isCompact ? .subheadline.weight(.semibold) : .callout.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.76)
                        .truncationMode(.tail)

                    if let subtitle = tag.displaySubtitle {
                        Text(subtitle)
                            .font(isCompact ? .caption2 : .caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .truncationMode(.tail)
                    }
                }
                .layoutPriority(1)

                Text(tag.count.formatted())
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, isCompact ? 6 : 7)
                    .padding(.vertical, isCompact ? 2 : 3)
                    .glassEffect(.regular, in: Capsule(style: .continuous))
            }
            .padding(.horizontal, isCompact ? 10 : 12)
            .padding(.vertical, compactVerticalPadding)
            .frame(
                minWidth: fillsAvailableWidth ? 0 : chipMinimumWidth,
                maxWidth: fillsAvailableWidth ? .infinity : chipMaximumWidth,
                alignment: .leading
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .help("# \(tag.name)")
        .accessibilityLabel(accessibilityLabel)
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var chipMinimumWidth: CGFloat {
        isCompact ? 124 : 150
    }

    private var chipMaximumWidth: CGFloat {
        isCompact ? 156 : 218
    }

    private var compactVerticalPadding: CGFloat {
        if isCompact {
            return tag.displaySubtitle == nil ? 7 : 6
        }
        return tag.displaySubtitle == nil ? 8 : 7
    }

    private var accessibilityLabel: String {
        if let subtitle = tag.displaySubtitle {
            return "# \(tag.name), \(subtitle), \(tag.count.formatted())"
        }
        return "# \(tag.name), \(tag.count.formatted())"
    }
}

private extension CreatorArtworkTag {
    var prefersFullWidthChip: Bool {
        name.estimatedDisplayColumns > 14
            || (displaySubtitle?.estimatedDisplayColumns ?? 0) > 22
    }
}

private extension String {
    var estimatedDisplayColumns: Int {
        unicodeScalars.reduce(0) { partialResult, scalar in
            partialResult + (scalar.isASCII ? 1 : 2)
        }
    }
}
