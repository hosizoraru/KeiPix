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

struct CreatorListHeader: View {
    let mode: UserPreviewListMode
    @Binding var restrict: BookmarkRestrict
    @Binding var creatorSearchText: String
    @Binding var creatorFilter: CreatorListFilter
    @Binding var creatorSort: CreatorListSort
    let isLoading: Bool
    let isRunningBulkAction: Bool
    let isCheckingFollowVisibility: Bool
    let hasActiveCreatorListState: Bool
    let visiblePreviewsCount: Int
    let visibleFollowedPreviewsCount: Int
    let bulkActionTargetCount: (CreatorBulkAction) -> Int
    let refreshCreatorList: () -> Void
    let checkVisibleFollowVisibility: () -> Void
    let resetCreatorListState: () -> Void
    let copyVisibleCreatorLinks: () -> Void
    let copyVisibleCreatorSummary: () -> Void
    let requestBulkAction: (CreatorBulkAction) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            if mode.usesRestrictPicker {
                Picker(L10n.followingCreators, selection: $restrict) {
                    Text(L10n.publicRestrict).tag(BookmarkRestrict.public)
                    Text(L10n.privateRestrict).tag(BookmarkRestrict.private)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 88)
                .accessibilityLabel(L10n.followingCreators)
            }

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(L10n.searchCreatorsInList, text: $creatorSearchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 260)
            }

            Button {
                creatorSearchText = ""
            } label: {
                Label(L10n.clearSearch, systemImage: "xmark.circle")
            }
            .labelStyle(.iconOnly)
            .disabled(creatorSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help(L10n.clearSearch)

            Menu {
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
                Label(L10n.creatorFilter, systemImage: "line.3.horizontal.decrease.circle")
                    .lineLimit(1)
            }
            .help("\(L10n.creatorFilter): \(creatorFilter.title) · \(L10n.creatorSort): \(creatorSort.title)")

            creatorActionsMenu
        }
        .controlSize(.small)
    }

    private var creatorActionsMenu: some View {
        Menu {
            Button {
                refreshCreatorList()
            } label: {
                Label(L10n.refresh, systemImage: "arrow.clockwise")
            }
            .disabled(isLoading)

            Button {
                checkVisibleFollowVisibility()
            } label: {
                Label(L10n.checkFollowVisibility, systemImage: "checkmark.seal")
            }
            .disabled(isCheckingFollowVisibility || visibleFollowedPreviewsCount == 0)

            Divider()

            Button {
                resetCreatorListState()
            } label: {
                Label(L10n.resetCreatorFilters, systemImage: "arrow.counterclockwise")
            }
            .disabled(hasActiveCreatorListState == false)

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
                ProgressView()
                    .controlSize(.small)
            } else {
                Label(L10n.creatorActions, systemImage: "slider.horizontal.3")
                    .labelStyle(.iconOnly)
            }
        }
        .help(L10n.creatorActions)
    }
}

struct CreatorPreviewListContent: View {
    let mode: UserPreviewListMode
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

    private let columns = [
        GridItem(.adaptive(minimum: 360, maximum: 520), spacing: 14)
    ]

    var body: some View {
        if mode.requiresSearchKeyword, searchKeyword.isEmpty {
            ContentUnavailableView(L10n.enterSearchKeyword, systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if previews.isEmpty {
            emptyState
        } else {
            ScrollView {
                Group {
                    if visiblePreviews.isEmpty {
                        noMatchingCreators
                    } else {
                        creatorGrid
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 20)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
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

    private var creatorGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(visiblePreviews) { preview in
                UserPreviewCard(
                    preview: preview,
                    followRestrict: followRestrictsByUserID[preview.user.id],
                    isUpdating: updatingCreatorIDs.contains(preview.user.id),
                    showContentBadges: showContentBadges,
                    maskSensitivePreviews: maskSensitivePreviews,
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
                    selectArtwork: selectArtwork
                )
            }

            if nextURL != nil {
                CreatorLoadMoreButton(isLoadingMore: isLoadingMore, loadMore: loadMore)
            }
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
