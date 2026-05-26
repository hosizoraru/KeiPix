import SwiftUI

/// Tappable stats strip — the sheet's primary navigation hub.
///
/// In the previous layout the same four totals (illustrations, manga,
/// public saves, following) were rendered twice: once as a static hero
/// strip, then again as a 6-cell "Collection Shortcuts" grid that
/// duplicated each number under a tappable card. That wasted ~120 pt of
/// vertical space on every sheet without adding new information.
///
/// Pixiv Web's profile collapses the duplication by making the **stats
/// themselves** the navigation: tapping `1.2K Illustrations` opens the
/// illustrations feed; tapping `3.4K Following` opens the following
/// list. Apple's Music artist sheet does the same for `Songs` /
/// `Albums` / `Followers`. We follow that pattern here so the numbers
/// stay scannable *and* every cell does double duty as a routing hub.
struct UserProfileStatsSection: View {
    let profile: PixivUserProfile?
    let openIllustrations: () -> Void
    let openManga: () -> Void
    let openPublicBookmarks: () -> Void
    let openFollowing: () -> Void

    private var entries: [Entry] {
        [
            Entry(
                title: L10n.illustrations,
                value: profile?.totalIllusts ?? 0,
                systemImage: "photo",
                action: openIllustrations
            ),
            Entry(
                title: L10n.manga,
                value: profile?.totalManga ?? 0,
                systemImage: "book.pages",
                action: openManga
            ),
            Entry(
                title: L10n.publicSaves,
                value: profile?.totalIllustBookmarksPublic ?? 0,
                systemImage: "bookmark",
                action: openPublicBookmarks
            ),
            Entry(
                title: L10n.followingCreators,
                value: profile?.totalFollowUsers ?? 0,
                systemImage: "person.2",
                action: openFollowing
            )
        ]
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ForEach(entries) { entry in
                if entry.id != entries.first?.id {
                    Divider()
                        .frame(height: 36)
                }
                ProfileStatCell(entry: entry)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
        .keiPanel(14)
    }

    fileprivate struct Entry: Identifiable {
        let title: String
        let value: Int
        let systemImage: String
        let action: () -> Void

        var id: String { title }
    }
}

private struct ProfileStatCell: View {
    let entry: UserProfileStatsSection.Entry
    @State private var isHovering = false

    var body: some View {
        Button(action: entry.action) {
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: entry.systemImage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.value.formatted(.number.notation(.compactName)))
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(entry.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(isHovering ? 0.06 : 0))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("\(entry.title) · \(entry.value.formatted())")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title): \(entry.value.formatted())")
        .accessibilityAddTraits(.isButton)
    }
}

/// Compact "network" rail: followers + related creators.
///
/// These two routes don't have a numerical hero stat (we don't get a
/// follower count from Pixiv's app API, and "related" is dynamic), so
/// they don't fit into `UserProfileStatsSection`. Splitting them off
/// into a chip rail mirrors Pixiv Web's `Following / Followers / 朋友`
/// sub-row right under the main stats.
struct UserProfileNetworkLinks: View {
    let relatedUsersCount: Int
    let isLoadingRelatedUsers: Bool
    let openFollowers: () -> Void
    let openRelated: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            networkChip(
                title: L10n.followers,
                badge: nil,
                systemImage: "person.2",
                isLoading: false,
                action: openFollowers
            )

            networkChip(
                title: L10n.relatedCreators,
                badge: relatedUsersCount > 0
                    ? "\(relatedUsersCount.formatted())+"
                    : nil,
                systemImage: "person.3",
                isLoading: isLoadingRelatedUsers,
                action: openRelated
            )
            .disabled(isLoadingRelatedUsers)

            Spacer(minLength: 0)
        }
    }

    private func networkChip(
        title: String,
        badge: String?,
        systemImage: String,
        isLoading: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .imageScale(.small)
                Text(title)
                    .font(.caption.weight(.medium))
                if let badge {
                    Text(badge)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
                if isLoading {
                    ProgressView().controlSize(.small)
                }
                Image(systemName: "chevron.forward")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(title)
    }
}

/// Long-form bio with an "expand" affordance.
///
/// Pixiv bios run from a single line to many paragraphs of HTML; the old
/// version always rendered the full thing, which pushed the busy
/// recent-works carousel out of the first viewport. We collapse to four
/// lines and let users tap "Show more" — same pattern App Store uses for
/// app descriptions.
struct UserProfileDescriptionSection: View {
    let text: String?

    @State private var isExpanded = false

    private let collapsedLineLimit = 4

    var body: some View {
        if let text, text.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Label(L10n.description, systemImage: "text.alignleft")
                        .font(.headline)
                    Spacer(minLength: 0)
                    if shouldOfferToggle(for: text) {
                        Button(isExpanded ? L10n.showLess : L10n.showMore) {
                            withAnimation(.snappy(duration: 0.18)) {
                                isExpanded.toggle()
                            }
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                }

                Text(text)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(isExpanded ? nil : collapsedLineLimit)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .padding(16)
            .keiPanel(16)
        }
    }

    /// Show the toggle when the text is *probably* longer than the
    /// collapsed limit. We can't measure the rendered height without
    /// reaching for `GeometryReader`, so we approximate: ~52 chars per
    /// line on the sheet width is a reasonable cut-off for Pixiv bios
    /// that mix CJK and Latin text.
    private func shouldOfferToggle(for text: String) -> Bool {
        text.contains("\n") || text.count > collapsedLineLimit * 52
    }
}

/// Links chip rail.
///
/// Originally each link was a `.bordered` button which made every entry
/// look like an action that needed clicking. Switching to chip-style
/// links + a single inline "region · job" footer keeps the eye on what
/// the section is actually about: contact + locale.
struct UserProfileLinksSection: View {
    let user: PixivUser
    let profile: PixivUserProfile?

    var body: some View {
        if hasContent {
            VStack(alignment: .leading, spacing: 10) {
                Label(L10n.links, systemImage: "link")
                    .font(.headline)

                if visibleEntries.isEmpty == false {
                    FlowLayout(spacing: 8) {
                        ForEach(visibleEntries, id: \.title) { entry in
                            Link(destination: entry.url) {
                                HStack(spacing: 6) {
                                    Image(systemName: entry.systemImage)
                                        .imageScale(.small)
                                    Text(entry.title)
                                }
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.quinary, in: Capsule())
                                .overlay {
                                    Capsule().stroke(.quaternary, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .help(entry.url.absoluteString)
                        }
                    }
                }

                if regionAndJobLine.isEmpty == false {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(regionAndJobLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(16)
            .keiPanel(16)
        }
    }

    private struct LinkEntry {
        let title: String
        let systemImage: String
        let url: URL
    }

    private var visibleEntries: [LinkEntry] {
        var entries: [LinkEntry] = []
        if let url = user.pixivURL {
            entries.append(LinkEntry(title: "Pixiv", systemImage: "safari", url: url))
        }
        if let url = profile?.webpage {
            entries.append(LinkEntry(title: "Web", systemImage: "globe", url: url))
        }
        if let url = profile?.twitterURL {
            entries.append(LinkEntry(title: "X", systemImage: "bird", url: url))
        }
        if let url = profile?.pawooURL {
            entries.append(LinkEntry(title: "Pawoo", systemImage: "at", url: url))
        }
        return entries
    }

    private var regionAndJobLine: String {
        let region = profile?.region?.trimmedNonEmpty
        let job = profile?.job?.trimmedNonEmpty
        return [region, job].compactMap { $0 }.joined(separator: " · ")
    }

    private var hasContent: Bool {
        visibleEntries.isEmpty == false || regionAndJobLine.isEmpty == false
    }
}

/// Workspace section.
///
/// Most Pixiv creators leave this empty, so we hide the panel entirely
/// when there's nothing to render. When there *is* content, render
/// title/value pairs in a Grid so columns align even when values vary
/// in length.
struct UserProfileWorkspaceSection: View {
    let workspace: PixivUserWorkspace?

    var body: some View {
        if let workspace {
            let entries = workspace.infoEntries
            let comment = workspace.trimmedComment

            if entries.isEmpty == false || comment != nil {
                VStack(alignment: .leading, spacing: 10) {
                    Label(L10n.workspace, systemImage: "paintbrush.pointed")
                        .font(.headline)

                    if entries.isEmpty == false {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                            ForEach(entries, id: \.title) { entry in
                                GridRow {
                                    Text(entry.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .gridColumnAlignment(.leading)
                                    Text(entry.value)
                                        .font(.callout)
                                        .foregroundStyle(.primary)
                                        .textSelection(.enabled)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }

                    if let comment {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.workspaceComment)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(comment)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(16)
                .keiPanel(16)
            }
        }
    }
}

struct ProfileInfoLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
        }
    }
}

extension PixivUserWorkspace {
    var infoEntries: [(title: String, value: String)] {
        [
            (L10n.tool, tool),
            (L10n.tablet, tablet),
            (L10n.mouse, mouse)
        ].compactMap { title, value in
            guard let trimmed = value?.trimmedNonEmpty else { return nil }
            return (title, trimmed)
        }
    }

    var trimmedComment: String? {
        comment?.htmlStripped.trimmedNonEmpty
    }
}

extension String {
    var trimmedNonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
