import SwiftUI

struct UserProfileSheet: View {
    let user: PixivUser
    @Bindable var store: KeiPixStore

    @Environment(\.dismiss) private var dismiss
    @State private var detail: PixivUserDetail?
    @State private var isLoading = true
    @State private var isLoadingRelatedUsers = false
    @State private var isFollowed: Bool
    @State private var relatedUsers: [PixivUserPreview] = []
    @State private var errorMessage: String?
    @State private var relatedErrorMessage: String?
    @State private var statusMessage: String?
    @State private var followRestrict: BookmarkRestrict?
    @State private var isUpdatingFollow = false
    @State private var updatingRelatedUserIDs: Set<Int> = []
    @State private var selectedRelatedUser: PixivUser?
    @State private var relationshipListMode: UserPreviewListMode?
    @State private var pendingDangerAction: AppDangerAction?
    @State private var feedbackRequest: FeedbackReportRequest?

    init(user: PixivUser, store: KeiPixStore) {
        self.user = user
        self.store = store
        _isFollowed = State(initialValue: user.isFollowed)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(40)
                    } else if detail == nil, let errorMessage {
                        ContentUnavailableView {
                            Label(L10n.errorTitle, systemImage: "exclamationmark.triangle")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button {
                                Task { await loadDetail() }
                            } label: {
                                Label(L10n.retry, systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 260)
                    } else {
                        UserProfileMetricsSection(profile: detail?.profile)
                        UserProfileCollectionShortcutsSection(
                            profile: detail?.profile,
                            relatedUsersCount: relatedUsers.count,
                            isLoadingRelatedUsers: isLoadingRelatedUsers,
                            openIllustrations: {
                                openFeed(.userIllustrations)
                            },
                            openManga: {
                                openFeed(.userManga)
                            },
                            openPublicBookmarks: {
                                openFeed(.userPublicBookmarks)
                            },
                            openFollowing: {
                                relationshipListMode = .userFollowing(detail?.user ?? user)
                            },
                            openFollowers: {
                                relationshipListMode = .userFollowers(detail?.user ?? user)
                            },
                            openRelated: {
                                relationshipListMode = .related(detail?.user ?? user)
                            }
                        )
                        UserProfileRecentWorksSection(
                            user: currentUser,
                            store: store,
                            openAllWorks: {
                                openFeed(.userIllustrations)
                            },
                            selectArtwork: { artwork in
                                store.selectedArtwork = artwork
                                dismiss()
                            },
                            showStatus: showStatus
                        )
                        UserProfileDescriptionSection(text: (detail?.user.comment ?? user.comment)?.htmlStripped)
                        UserProfileLinksSection(user: currentUser, profile: detail?.profile)
                        UserProfileWorkspaceSection(workspace: detail?.workspace)
                        UserProfileRelatedCreatorsSection(
                            relatedUsers: relatedUsers,
                            isLoadingRelatedUsers: isLoadingRelatedUsers,
                            relatedErrorMessage: relatedErrorMessage,
                            updatingRelatedUserIDs: updatingRelatedUserIDs,
                            reload: {
                                Task { await loadRelatedUsers() }
                            },
                            viewAll: {
                                relationshipListMode = .related(detail?.user ?? user)
                            },
                            openProfile: { relatedUser in
                                selectedRelatedUser = relatedUser
                            },
                            openIllustrations: { relatedUser in
                                Task {
                                    await store.openUserFeed(user: relatedUser, route: .userIllustrations)
                                    dismiss()
                                }
                            },
                            toggleFollow: { relatedUser, restrict in
                                Task { await toggleRelatedFollow(relatedUser, restrict: restrict) }
                            },
                            requestUnfollow: { relatedUser in
                                pendingDangerAction = AppDangerAction(
                                    kind: .unfollowCreator(relatedUser, nil)
                                )
                            },
                            requestMuteCreator: { relatedUser in
                                pendingDangerAction = AppDangerAction(kind: .muteCreator(relatedUser))
                            },
                            copied: {
                                showStatus(L10n.copied)
                            },
                            selectArtwork: { artwork in
                                store.selectedArtwork = artwork
                                dismiss()
                            }
                        )
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 580)
        .frame(minHeight: 520)
        .task(id: user.id) {
            await loadDetail()
            await loadRelatedUsers()
        }
        .sheet(item: $selectedRelatedUser) { relatedUser in
            UserProfileSheet(user: relatedUser, store: store)
        }
        .sheet(item: $relationshipListMode) { mode in
            UserPreviewListView(store: store, mode: mode)
                .frame(width: 920, height: 680)
        }
        .sheet(item: $feedbackRequest) { request in
            FeedbackReportSheet(request: request) {
                pendingDangerAction = AppDangerAction(kind: .muteCreator(currentUser))
            } onComplete: { message in
                showStatus(message)
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let statusMessage {
                    FloatingStatusBanner {
                        Text(statusMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let undoAction = store.undoAction {
                    AppUndoBar(action: undoAction) {
                        Task { await performUndo(undoAction) }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .animation(.snappy(duration: 0.18), value: statusMessage)
        .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
        .confirmationDialog(
            pendingDangerAction?.title ?? L10n.moreActions,
            isPresented: dangerActionBinding,
            titleVisibility: .visible
        ) {
            if let pendingDangerAction {
                Button(pendingDangerAction.title, role: .destructive) {
                    Task { await performDangerAction(pendingDangerAction) }
                }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            if let pendingDangerAction {
                Text(pendingDangerAction.confirmationMessage)
            }
        }
    }

    private var header: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImageView(url: detail?.profile.backgroundImageURL)
                .frame(height: 138)
                .frame(maxWidth: .infinity)
                .clipped()
                .overlay(.ultraThinMaterial)

            HStack(alignment: .bottom, spacing: 14) {
                RemoteImageView(url: detail?.user.avatarURL ?? user.avatarURL)
                    .frame(width: 74, height: 74)
                    .clipShape(Circle())
                    .overlay {
                        Circle().stroke(.quaternary, lineWidth: 1)
                    }

                VStack(alignment: .leading, spacing: 4) {
                    Text(detail?.user.name ?? user.name)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                    Text("@\(detail?.user.account ?? user.account)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                followMenu
                profileActionsMenu
            }
            .padding(20)
        }
    }

    private var followMenu: some View {
        Group {
            if isFollowed {
                Menu {
                    Button(L10n.followPublicly) {
                        Task { await updateFollowVisibility(.public) }
                    }
                    .disabled(followRestrict == .public)

                    Button(L10n.followPrivately) {
                        Task { await updateFollowVisibility(.private) }
                    }
                    .disabled(followRestrict == .private)

                    Divider()

                    Button(role: .destructive) {
                        pendingDangerAction = AppDangerAction(kind: .unfollowCreator(currentUser, followRestrict))
                    } label: {
                        Label(L10n.unfollow, systemImage: "person.crop.circle.badge.minus")
                    }
                } label: {
                    Label(followStatusTitle, systemImage: followStatusImage)
                }
                .buttonStyle(.bordered)
            } else {
                Menu {
                    Button(L10n.followUsingDefault) {
                        Task { await toggleFollow() }
                    }

                    Divider()

                    Button(L10n.followPublicly) {
                        Task { await toggleFollow(restrict: .public) }
                    }
                    Button(L10n.followPrivately) {
                        Task { await toggleFollow(restrict: .private) }
                    }
                } label: {
                    Label(L10n.follow, systemImage: "person.crop.circle.badge.plus")
                }
                .buttonStyle(.glassProminent)
            }
        }
        .disabled(isLoading || isUpdatingFollow)
        .help(L10n.followVisibility)
    }

    @ViewBuilder
    private var profileActionsMenu: some View {
        if let url = currentUser.pixivURL {
            Menu {
                Link(L10n.openInPixiv, destination: url)

                Button(L10n.copyLink) {
                    PasteboardWriter.copy(url.absoluteString)
                    showStatus(L10n.copied)
                }

                Button {
                    let isPinned = store.togglePinnedCreator(currentUser)
                    showStatus(String(format: isPinned ? L10n.pinnedCreatorFormat : L10n.unpinnedCreatorFormat, currentUser.name))
                } label: {
                    Label(store.isPinnedCreator(currentUser) ? L10n.unpinCreator : L10n.pinCreator, systemImage: store.isPinnedCreator(currentUser) ? "pin.slash" : "pin")
                }

                Divider()

                Button {
                    feedbackRequest = .creator(currentUser)
                } label: {
                    Label(L10n.feedbackAndMute, systemImage: "exclamationmark.bubble")
                }
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.moreActions)
        }
    }

    private var followStatusTitle: String {
        followRestrict == .private ? L10n.followingPrivately : L10n.followingPublicly
    }

    private var followStatusImage: String {
        followRestrict == .private ? "lock.circle" : "person.crop.circle.badge.checkmark"
    }

    private var currentUser: PixivUser {
        detail?.user ?? user
    }

    private func openFeed(_ route: PixivRoute) {
        Task {
            await store.openUserFeed(user: currentUser, route: route)
            dismiss()
        }
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loaded = try await store.userDetail(for: user)
            detail = loaded
            isFollowed = loaded.user.isFollowed
            if loaded.user.isFollowed {
                await loadFollowDetail()
            } else {
                followRestrict = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadFollowDetail() async {
        do {
            let followDetail = try await store.followDetail(for: detail?.user ?? user)
            isFollowed = followDetail.isFollowed
            followRestrict = followDetail.isFollowed ? followDetail.restrictValue : nil
        } catch {
            followRestrict = nil
        }
    }

    private func loadRelatedUsers() async {
        isLoadingRelatedUsers = true
        relatedErrorMessage = nil
        defer { isLoadingRelatedUsers = false }

        do {
            let response = try await store.relatedUsers(for: user)
            relatedUsers = response.userPreviews.filter { $0.user.id != user.id }
        } catch {
            relatedErrorMessage = error.localizedDescription
        }
    }

    private func toggleFollow(restrict: BookmarkRestrict? = nil) async {
        guard isUpdatingFollow == false else { return }
        let target = detail?.user ?? user
        let nextValue = isFollowed == false
        let appliedRestrict = restrict ?? store.defaultFollowRestrict
        isUpdatingFollow = true
        defer { isUpdatingFollow = false }
        do {
            try await store.setFollow(target, isFollowed: nextValue, restrict: appliedRestrict)
            isFollowed = nextValue
            followRestrict = nextValue ? appliedRestrict : nil
            if nextValue {
                showStatus(String(format: L10n.followedCreatorFormat, target.name))
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func updateFollowVisibility(_ restrict: BookmarkRestrict) async {
        guard isUpdatingFollow == false else { return }
        let target = detail?.user ?? user
        isUpdatingFollow = true
        defer { isUpdatingFollow = false }
        do {
            try await store.setFollow(target, isFollowed: true, restrict: restrict)
            isFollowed = true
            followRestrict = restrict
            showStatus(String(format: L10n.updatedCreatorFollowVisibilityFormat, target.name))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleRelatedFollow(_ user: PixivUser, restrict: BookmarkRestrict? = nil) async {
        guard updatingRelatedUserIDs.contains(user.id) == false else { return }
        let nextValue = user.isFollowed == false
        let appliedRestrict = restrict ?? store.defaultFollowRestrict
        updatingRelatedUserIDs.insert(user.id)
        defer { updatingRelatedUserIDs.remove(user.id) }
        do {
            try await store.setFollow(user, isFollowed: nextValue, restrict: appliedRestrict)
        } catch {
            relatedErrorMessage = error.localizedDescription
            return
        }
        updateRelatedFollowState(userID: user.id, isFollowed: nextValue)
        if nextValue {
            showStatus(String(format: L10n.followedCreatorFormat, user.name))
        }
    }

    private func performDangerAction(_ action: AppDangerAction) async {
        defer { pendingDangerAction = nil }
        let succeeded = await store.performDangerAction(action)
        guard succeeded else {
            errorMessage = store.errorMessage
            return
        }

        switch action.kind {
        case .unfollowCreator(let user, _):
            if user.id == currentUser.id {
                isFollowed = false
                followRestrict = nil
            }
            updateRelatedFollowState(userID: user.id, isFollowed: false)
            showStatus(String(format: L10n.unfollowedCreatorFormat, user.name))
        case .muteCreator(let user):
            updateRelatedMutedState(userID: user.id, isMuted: true)
            showStatus(String(format: L10n.mutedCreatorFormat, user.name))
        case .removeBookmark, .muteArtwork, .muteTag:
            break
        }
    }

    private func performUndo(_ action: AppUndoAction) async {
        await store.performUndo(action)

        switch action.kind {
        case .restoreFollow(let user, let restrict):
            if user.id == currentUser.id {
                isFollowed = true
                followRestrict = restrict
            }
            updateRelatedFollowState(userID: user.id, isFollowed: true)
            showStatus(String(format: L10n.followedCreatorFormat, user.name))
        case .unmuteCreator(let user):
            updateRelatedMutedState(userID: user.id, isMuted: false)
        default:
            break
        }
    }

    private var dangerActionBinding: Binding<Bool> {
        Binding {
            pendingDangerAction != nil
        } set: { value in
            if value == false {
                pendingDangerAction = nil
            }
        }
    }

    private func updateRelatedFollowState(userID: Int, isFollowed: Bool) {
        for index in relatedUsers.indices where relatedUsers[index].user.id == userID {
            var updatedUser = relatedUsers[index].user
            updatedUser.isFollowed = isFollowed
            relatedUsers[index] = PixivUserPreview(
                user: updatedUser,
                illusts: relatedUsers[index].illusts,
                isMuted: relatedUsers[index].isMuted
            )
        }
    }

    private func updateRelatedMutedState(userID: Int, isMuted: Bool) {
        for index in relatedUsers.indices where relatedUsers[index].user.id == userID {
            relatedUsers[index] = PixivUserPreview(
                user: relatedUsers[index].user,
                illusts: relatedUsers[index].illusts,
                isMuted: isMuted
            )
        }
    }

    private func showStatus(_ message: String) {
        statusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if statusMessage == message {
                statusMessage = nil
            }
        }
    }
}
