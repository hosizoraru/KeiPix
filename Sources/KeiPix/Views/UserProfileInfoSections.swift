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
    let openNovels: () -> Void
    let openPublicBookmarks: () -> Void
    let openFollowing: () -> Void
    let openFollowers: () -> Void
    let openMyPixiv: () -> Void
    let openRelated: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 8 : 10) {
            GlassEffectContainer(spacing: 8) {
                overviewGrid
            }
        }
        .padding(isCompact ? 8 : 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var overviewGrid: some View {
        LazyVGrid(columns: overviewColumns, alignment: .leading, spacing: 8) {
            ForEach(overviewEntries) { entry in
                ProfileStatCell(entry: entry, isCompact: isCompact || isNarrowRegularWidth)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var overviewEntries: [UserProfileStatEntry] {
        [
            UserProfileStatEntry(
                title: L10n.illustrations,
                valueLabel: (profile?.totalIllusts ?? 0).formatted(),
                systemImage: "photo",
                action: openIllustrations
            ),
            UserProfileStatEntry(
                title: L10n.manga,
                valueLabel: (profile?.totalManga ?? 0).formatted(),
                systemImage: "book.pages",
                action: openManga
            ),
            UserProfileStatEntry(
                title: L10n.novels,
                valueLabel: L10n.open,
                systemImage: "text.book.closed",
                action: openNovels
            ),
            UserProfileStatEntry(
                title: L10n.publicSaves,
                valueLabel: (profile?.totalIllustBookmarksPublic ?? 0).formatted(),
                systemImage: "bookmark",
                action: openPublicBookmarks
            ),
            UserProfileStatEntry(
                title: L10n.followingCreators,
                valueLabel: (profile?.totalFollowUsers ?? 0).formatted(),
                systemImage: "person.2",
                action: openFollowing
            ),
            UserProfileStatEntry(
                title: L10n.followers,
                valueLabel: L10n.open,
                systemImage: "person.2.wave.2",
                action: openFollowers
            ),
            UserProfileStatEntry(
                title: L10n.myPixivUsers,
                valueLabel: (profile?.totalMyPixivUsers ?? 0).formatted(),
                systemImage: "person.2.crop.square.stack",
                action: openMyPixiv
            ),
            UserProfileStatEntry(
                title: L10n.relatedCreators,
                valueLabel: relatedUsersCount > 0 ? "\(relatedUsersCount.formatted())+" : L10n.open,
                systemImage: isLoadingRelatedUsers ? "hourglass" : "person.3",
                isEnabled: isLoadingRelatedUsers == false,
                action: openRelated
            )
        ]
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var isNarrowRegularWidth: Bool {
        #if os(macOS)
        false
        #else
        horizontalSizeClass != .regular
        #endif
    }

    private var overviewColumns: [GridItem] {
        if isCompact {
            return [
                GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8),
                GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8),
                GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8)
            ]
        }
        return [
            GridItem(.adaptive(minimum: 92, maximum: 122), spacing: 8)
        ]
    }
}

private struct UserProfileStatEntry: Identifiable {
    let title: String
    let valueLabel: String
    let systemImage: String
    var isEnabled = true
    let action: () -> Void

    var id: String { title }
}

private struct ProfileStatCell: View {
    let entry: UserProfileStatEntry
    let isCompact: Bool
    @State private var isHovering = false

    var body: some View {
        Button(action: entry.action) {
            VStack(spacing: isCompact ? 2 : 3) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: entry.systemImage)
                        .font(isCompact ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                    Text(entry.valueLabel)
                        .font((isCompact ? Font.subheadline : Font.title3).weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                Text(entry.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(minWidth: isCompact ? 0 : 92, maxWidth: .infinity)
            .padding(.vertical, isCompact ? 6 : 7)
            .padding(.horizontal, isCompact ? 5 : 9)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .disabled(entry.isEnabled == false)
        .scaleEffect(isHovering ? 1.012 : 1)
        .keiPixHoverTracker { isHovering = $0 }
        .animation(.snappy(duration: 0.16), value: isHovering)
        .help("\(entry.title) · \(entry.valueLabel)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.title): \(entry.valueLabel)")
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
