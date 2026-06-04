import SwiftUI

/// Compact overview hub for creator profile sheets.
///
/// Stats and relationship entry points are one conceptual area: "where can I
/// go next for this creator?" Keeping them in one glass surface gives iPadOS
/// more first-viewport content and makes the macOS sheet feel less like a
/// stack of old preference cards.
struct UserProfileOverviewSection: View {
    let profile: PixivUserProfile?
    let relatedUsersCount: Int
    let isLoadingRelatedUsers: Bool
    let openIllustrations: () -> Void
    let openManga: () -> Void
    let openPublicBookmarks: () -> Void
    let openFollowing: () -> Void
    let openFollowers: () -> Void
    let openRelated: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GlassEffectContainer(spacing: 8) {
                ViewThatFits(in: .horizontal) {
                    wideOverviewRow
                    compactOverviewStack
                }
            }
        }
        .padding(10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var wideOverviewRow: some View {
        HStack(spacing: 8) {
            statsRow
            Divider()
                .frame(height: 34)
                .opacity(0.45)
            Spacer(minLength: 8)
            networkRail
        }
    }

    private var compactOverviewStack: some View {
        VStack(alignment: .leading, spacing: 10) {
            statsRow
                .frame(maxWidth: .infinity, alignment: .leading)
            networkRail
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var statsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(statEntries) { entry in
                    ProfileStatCell(entry: entry)
                }
            }

            compactStatsGrid
        }
    }

    private var compactStatsGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(statEntries.prefix(2)) { entry in
                    ProfileStatCell(entry: entry)
                }
            }

            HStack(spacing: 8) {
                ForEach(statEntries.dropFirst(2)) { entry in
                    ProfileStatCell(entry: entry)
                }
            }
        }
    }

    private var networkRail: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                followersChip
                relatedCreatorsChip
            }

            VStack(alignment: .leading, spacing: 8) {
                followersChip
                relatedCreatorsChip
            }
        }
    }

    private var followersChip: some View {
        networkChip(
            title: L10n.followers,
            badge: nil,
            systemImage: "person.2",
            isLoading: false,
            action: openFollowers
        )
    }

    private var relatedCreatorsChip: some View {
        networkChip(
            title: L10n.relatedCreators,
            badge: relatedUsersCount > 0 ? "\(relatedUsersCount.formatted())+" : nil,
            systemImage: "person.3",
            isLoading: isLoadingRelatedUsers,
            action: openRelated
        )
        .disabled(isLoadingRelatedUsers)
    }

    private var statEntries: [UserProfileStatEntry] {
        [
            UserProfileStatEntry(
                title: L10n.illustrations,
                value: profile?.totalIllusts ?? 0,
                systemImage: "photo",
                action: openIllustrations
            ),
            UserProfileStatEntry(
                title: L10n.manga,
                value: profile?.totalManga ?? 0,
                systemImage: "book.pages",
                action: openManga
            ),
            UserProfileStatEntry(
                title: L10n.publicSaves,
                value: profile?.totalIllustBookmarksPublic ?? 0,
                systemImage: "bookmark",
                action: openPublicBookmarks
            ),
            UserProfileStatEntry(
                title: L10n.followingCreators,
                value: profile?.totalFollowUsers ?? 0,
                systemImage: "person.2",
                action: openFollowing
            )
        ]
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
                    .lineLimit(1)
                if let badge {
                    Text(badge)
                        .font(.caption2.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .glassEffect(.regular, in: Capsule(style: .continuous))
                }
                if isLoading {
                    ProgressView().controlSize(.small)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
        .help(title)
    }
}

private struct UserProfileStatEntry: Identifiable {
    let title: String
    let value: Int
    let systemImage: String
    let action: () -> Void

    var id: String { title }
}

private struct ProfileStatCell: View {
    let entry: UserProfileStatEntry
    @State private var isHovering = false

    var body: some View {
        Button(action: entry.action) {
            VStack(spacing: 3) {
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
            .frame(minWidth: 92)
            .padding(.vertical, 7)
            .padding(.horizontal, 9)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(isHovering ? 1.012 : 1)
        .keiPixHoverTracker { isHovering = $0 }
        .animation(.snappy(duration: 0.16), value: isHovering)
        .help("\(entry.title) · \(entry.value.formatted())")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title): \(entry.value.formatted())")
        .accessibilityAddTraits(.isButton)
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
                        .buttonStyle(.glass)
                        .buttonBorderShape(.capsule)
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
            .padding(14)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                .padding(14)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
