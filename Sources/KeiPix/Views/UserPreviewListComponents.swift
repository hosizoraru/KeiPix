import SwiftUI

struct CreatorListStatusBanner: View {
    let errorMessage: String?
    let bulkStatusText: String?
    let isRunningBulkAction: Bool
    let isCheckingFollowVisibility: Bool
    let undoAction: CreatorUndoAction?
    let performUndo: (CreatorUndoAction) -> Void

    var body: some View {
        FloatingStatusBanner {
            VStack(alignment: .leading, spacing: 6) {
                if let undoAction {
                    HStack(spacing: 10) {
                        Text(undoAction.message)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Button(L10n.undo) {
                            performUndo(undoAction)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                if isCheckingFollowVisibility {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.checkingFollowVisibility)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                if isRunningBulkAction {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.runningCreatorAction)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }

                if let bulkStatusText {
                    Text(bulkStatusText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
    }
}

/// Thin search bar that lives at the top of the creator list body.
///
/// The previous `CreatorListHeader` mixed the search field with five
/// other controls (filter / sort / layout / bulk actions / refresh)
/// in a `FlowLayout` band. Apple's HIG and stock surfaces (Mail, Music,
/// Photos) keep search at the body edge but push view options /
/// destructive bulk actions into the toolbar so the body stays
/// scannable. `CreatorListSearchBar` is the slim body half — the rest
/// moved into `UserPreviewListView.toolbar`.
struct CreatorListSearchBar: View {
    let mode: UserPreviewListMode
    @Binding var restrict: BookmarkRestrict
    @Binding var creatorSearchText: String

    var body: some View {
        HStack(spacing: 10) {
            if mode.usesRestrictPicker {
                Picker(L10n.followingCreators, selection: $restrict) {
                    Text(L10n.publicRestrict).tag(BookmarkRestrict.public)
                    Text(L10n.privateRestrict).tag(BookmarkRestrict.private)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 96)
                .accessibilityLabel(L10n.followingCreators)
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                NativeSearchField(
                    text: $creatorSearchText,
                    placeholder: L10n.searchCreatorsInList,
                    suggestions: [],
                    onSubmit: {},
                    onTextChange: { creatorSearchText = $0 }
                )
                .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: 360)

            if creatorSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
                Button {
                    creatorSearchText = ""
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle.fill")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help(L10n.clearSearch)
            }

            Spacer(minLength: 0)
        }
        .controlSize(.small)
    }
}

/// View-options menu rendered in the creator list's toolbar. Combines
/// the filter and sort pickers in one dropdown — Apple Mail's "Sort"
/// menu, Photos's "View Options" menu, and Music's "Sort By" menu all
/// share this Picker(.inline) inside a Menu pattern.
struct CreatorListViewOptionsMenu: View {
    @Binding var creatorFilter: CreatorListFilter
    @Binding var creatorSort: CreatorListSort
    @Binding var layoutMode: CreatorListLayoutMode

    var body: some View {
        Menu {
            Picker(L10n.creatorListLayout, selection: $layoutMode) {
                ForEach(CreatorListLayoutMode.allCases) { mode in
                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Picker(L10n.creatorFilter, selection: $creatorFilter) {
                ForEach(CreatorListFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.inline)

            Divider()

            Picker(L10n.creatorSort, selection: $creatorSort) {
                ForEach(CreatorListSort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Label(L10n.viewOptions, systemImage: "slider.horizontal.3")
        }
        .labelStyle(.iconOnly)
        .help(L10n.viewOptions)
    }
}

/// Bulk-action menu rendered in the creator list's toolbar. The menu
/// includes verification (Check follow visibility), copy helpers, and
/// destructive bulk operations. Empty rows disable themselves so the
/// menu is always shown but never lies about what it can do.
struct CreatorListBulkActionsMenu: View {
    let isRunningBulkAction: Bool
    let isCheckingFollowVisibility: Bool
    let visiblePreviewsCount: Int
    let visibleFollowedPreviewsCount: Int
    let bulkActionTargetCount: (CreatorBulkAction) -> Int
    let checkVisibleFollowVisibility: () -> Void
    let copyVisibleCreatorLinks: () -> Void
    let copyVisibleCreatorSummary: () -> Void
    let requestBulkAction: (CreatorBulkAction) -> Void

    var body: some View {
        #if os(macOS)
        EnhancedMenu(sections: enhancedMenuSections) { item in
            handleEnhancedMenuItem(item)
        }
        .help(L10n.creatorActions)
        #else
        swiftUIMenu
        #endif
    }

    private var swiftUIMenu: some View {
        Menu {
            Button {
                checkVisibleFollowVisibility()
            } label: {
                Label(L10n.checkFollowVisibility, systemImage: "checkmark.seal")
            }
            .disabled(isCheckingFollowVisibility || visibleFollowedPreviewsCount == 0)

            Divider()

            Button {
                copyVisibleCreatorLinks()
            } label: {
                Label(L10n.copyVisibleCreatorLinks, systemImage: "link")
            }
            .disabled(visiblePreviewsCount == 0)

            Button {
                copyVisibleCreatorSummary()
            } label: {
                Label(L10n.copyVisibleCreatorSummary, systemImage: "doc.text")
            }
            .disabled(visiblePreviewsCount == 0)

            Divider()

            Button {
                requestBulkAction(.followPublic)
            } label: {
                Label(L10n.followVisiblePublicly, systemImage: "person.crop.circle.badge.plus")
            }
            .disabled(isRunningBulkAction || bulkActionTargetCount(.followPublic) == 0)

            Button {
                requestBulkAction(.followPrivate)
            } label: {
                Label(L10n.followVisiblePrivately, systemImage: "lock.circle")
            }
            .disabled(isRunningBulkAction || bulkActionTargetCount(.followPrivate) == 0)

            Divider()

            Button(role: .destructive) {
                requestBulkAction(.mute)
            } label: {
                Label(L10n.muteVisibleCreators, systemImage: "eye.slash")
            }
            .disabled(isRunningBulkAction || bulkActionTargetCount(.mute) == 0)

            Button(role: .destructive) {
                requestBulkAction(.unfollow)
            } label: {
                Label(L10n.unfollowVisibleCreators, systemImage: "person.crop.circle.badge.minus")
            }
            .disabled(isRunningBulkAction || bulkActionTargetCount(.unfollow) == 0)
        } label: {
            if isRunningBulkAction {
                ProgressView().controlSize(.small)
            } else {
                Label(L10n.creatorActions, systemImage: "ellipsis.circle")
            }
        }
        .labelStyle(.iconOnly)
        .help(L10n.creatorActions)
    }

    #if os(macOS)
    private var enhancedMenuSections: [MenuSection] {
        [
            MenuSection(
                title: L10n.checkFollowVisibility,
                items: [
                    MenuItem(
                        title: L10n.checkFollowVisibility,
                        icon: menuIcon("checkmark.seal"),
                        isEnabled: isCheckingFollowVisibility == false && visibleFollowedPreviewsCount > 0,
                        action: .checkFollowVisibility
                    )
                ]
            ),
            MenuSection(
                title: L10n.visibleCreators,
                items: [
                    MenuItem(
                        title: L10n.copyVisibleCreatorLinks,
                        icon: menuIcon("link"),
                        isEnabled: visiblePreviewsCount > 0,
                        action: .copyVisibleCreatorLinks
                    ),
                    MenuItem(
                        title: L10n.copyVisibleCreatorSummary,
                        icon: menuIcon("doc.text"),
                        isEnabled: visiblePreviewsCount > 0,
                        action: .copyVisibleCreatorSummary
                    )
                ]
            ),
            MenuSection(
                title: L10n.following,
                items: [
                    MenuItem(
                        title: L10n.followVisiblePublicly,
                        icon: menuIcon("person.crop.circle.badge.plus"),
                        isEnabled: isRunningBulkAction == false && bulkActionTargetCount(.followPublic) > 0,
                        action: .followPublic
                    ),
                    MenuItem(
                        title: L10n.followVisiblePrivately,
                        icon: menuIcon("lock.circle"),
                        isEnabled: isRunningBulkAction == false && bulkActionTargetCount(.followPrivate) > 0,
                        action: .followPrivate
                    )
                ]
            ),
            MenuSection(
                title: L10n.creatorActions,
                items: [
                    MenuItem(
                        title: L10n.muteVisibleCreators,
                        icon: menuIcon("eye.slash"),
                        isEnabled: isRunningBulkAction == false && bulkActionTargetCount(.mute) > 0,
                        action: .mute
                    ),
                    MenuItem(
                        title: L10n.unfollowVisibleCreators,
                        icon: menuIcon("person.crop.circle.badge.minus"),
                        isEnabled: isRunningBulkAction == false && bulkActionTargetCount(.unfollow) > 0,
                        action: .unfollow
                    )
                ]
            )
        ]
    }

    private func handleEnhancedMenuItem(_ item: MenuItem) {
        switch item.action {
        case .checkFollowVisibility:
            checkVisibleFollowVisibility()
        case .copyVisibleCreatorLinks:
            copyVisibleCreatorLinks()
        case .copyVisibleCreatorSummary:
            copyVisibleCreatorSummary()
        case .followPublic:
            requestBulkAction(.followPublic)
        case .followPrivate:
            requestBulkAction(.followPrivate)
        case .mute:
            requestBulkAction(.mute)
        case .unfollow:
            requestBulkAction(.unfollow)
        default:
            break
        }
    }

    private func menuIcon(_ systemName: String) -> NSImage? {
        NSImage(systemSymbolName: systemName, accessibilityDescription: nil)
    }
    #endif
}

struct CreatorPreviewListContent: View {
    let mode: UserPreviewListMode
    let layoutMode: CreatorListLayoutMode
    let searchKeyword: String
    let previews: [PixivUserPreview]
    let visiblePreviews: [PixivUserPreview]
    let nextURL: URL?
    let errorMessage: String?
    let isLoadingMore: Bool
    let followRestrictsByUserID: [Int: BookmarkRestrict]
    let updatingCreatorIDs: Set<Int>
    let showContentBadges: Bool
    let maskSensitivePreviews: Bool
    let retry: () -> Void
    let loadMore: () -> Void
    let openProfile: (PixivUser) -> Void
    let openIllustrations: (PixivUser) -> Void
    let openManga: (PixivUser) -> Void
    let followCreator: (PixivUser, BookmarkRestrict?) -> Void
    let requestUnfollow: (PixivUser) -> Void
    let requestMuteCreator: (PixivUser) -> Void
    let requestFeedback: (PixivUser) -> Void
    let copyCreatorLink: (PixivUser) -> Void
    let copyArtworkLink: (PixivArtwork) -> Void
    let isPinnedCreator: (PixivUser) -> Bool
    let togglePinnedCreator: (PixivUser) -> Void
    let selectArtwork: (PixivArtwork) -> Void
    /// Lazy fetcher used when `layoutMode == .single`. The single-card
    /// shelf calls into this to surface more than the 3 illustrations
    /// Pixiv ships in the recommended-users / related-users response.
    let loadCreatorPreviewArtworks: (PixivUser) async throws -> [PixivArtwork]

    var body: some View {
        if mode.requiresSearchKeyword, searchKeyword.isEmpty {
            ContentUnavailableView(L10n.enterSearchKeyword, systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if previews.isEmpty {
            emptyState
        } else if visiblePreviews.isEmpty {
            ScrollView {
                noMatchingCreators
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 20)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            NativeCreatorPreviewCollectionView(
                items: creatorCollectionItems,
                layout: NativeCreatorPreviewCollectionLayout(mode: layoutMode)
            ) { item in
                nativeCreatorPreviewContent(for: item)
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let errorMessage {
            ContentUnavailableView {
                Label(L10n.errorTitle, systemImage: "exclamationmark.triangle")
            } description: {
                Text(errorMessage)
            } actions: {
                Button {
                    retry()
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                emptyTitle,
                systemImage: mode.emptySystemImage,
                description: Text(emptyHint)
            )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyTitle: String {
        if case .pinned = mode {
            return L10n.noPinnedCreators
        }
        return L10n.noCreators
    }

    private var emptyHint: String {
        if case .pinned = mode {
            return L10n.noPinnedCreatorsHint
        }
        return ""
    }

    private var noMatchingCreators: some View {
        VStack(spacing: 14) {
            ContentUnavailableView(L10n.noMatchingCreators, systemImage: "person.crop.circle.badge.questionmark")
                .frame(maxWidth: .infinity)
                .frame(minHeight: 260)

            if nextURL != nil {
                CreatorLoadMoreButton(isLoadingMore: isLoadingMore, loadMore: loadMore)
                    .frame(maxWidth: 420)
            }
        }
    }

    private var creatorCollectionItems: [NativeCreatorPreviewCollectionItem] {
        var items = visiblePreviews.map(NativeCreatorPreviewCollectionItem.preview)
        if nextURL != nil {
            items.append(.loadMore)
        }
        return items
    }

    private func nativeCreatorPreviewContent(for item: NativeCreatorPreviewCollectionItem) -> AnyView {
        switch item {
        case .preview(let preview):
            return AnyView(
                UserPreviewCard(
                    preview: preview,
                    followRestrict: followRestrictsByUserID[preview.user.id],
                    isUpdating: updatingCreatorIDs.contains(preview.user.id),
                    showContentBadges: showContentBadges,
                    maskSensitivePreviews: maskSensitivePreviews,
                    expandedPreview: layoutMode.usesExpandedPreview,
                    openProfile: { openProfile(preview.user) },
                    openIllustrations: { openIllustrations(preview.user) },
                    openManga: { openManga(preview.user) },
                    followCreator: { restrict in followCreator(preview.user, restrict) },
                    requestUnfollow: { requestUnfollow(preview.user) },
                    requestMuteCreator: { requestMuteCreator(preview.user) },
                    requestFeedback: { requestFeedback(preview.user) },
                    copyCreatorLink: { copyCreatorLink(preview.user) },
                    copyArtworkLink: copyArtworkLink,
                    isPinned: isPinnedCreator(preview.user),
                    togglePinnedCreator: { togglePinnedCreator(preview.user) },
                    selectArtwork: selectArtwork,
                    loadExpandedArtworks: layoutMode.usesExpandedPreview
                        ? { try await loadCreatorPreviewArtworks(preview.user) }
                        : nil
                )
            )
        case .loadMore:
            return AnyView(
                CreatorLoadMoreButton(isLoadingMore: isLoadingMore, loadMore: loadMore)
            )
        }
    }
}

private struct CreatorLoadMoreButton: View {
    let isLoadingMore: Bool
    let loadMore: () -> Void

    var body: some View {
        Button {
            loadMore()
        } label: {
            VStack(spacing: 8) {
                if isLoadingMore {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                    Text(L10n.loadMoreCreators)
                        .font(.caption.weight(.medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 160)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(16)
        .disabled(isLoadingMore)
    }
}
