import SwiftUI
#if os(iOS)
import UIKit
#endif

struct PixivActivityFeedView: View {
    @Bindable var store: KeiPixStore
    @State private var actionMessage: String?
    @State private var presentedActivityDetail: PixivActivityDetailSheet?

    var body: some View {
        Group {
            if store.session == nil {
                PixivSignedOutStateView(store: store)
            } else if store.pixivWebSession?.isUsable != true {
                webSessionState
            } else {
                contentBody
            }
        }
        .platformPageHeader(
            title: L10n.pixivActivity,
            status: statusText,
            statusSystemImage: PixivRoute.pixivActivity.systemImage
        ) {
            #if os(macOS)
            titleActions
            #endif
        }
        .platformPageNavigationChrome(title: L10n.pixivActivity, status: statusText)
        .sheet(item: $presentedActivityDetail) { detail in
            NavigationStack {
                switch detail {
                case .artwork:
                    if store.selectedArtwork != nil {
                        ArtworkDetailView(store: store, showsNavigationChrome: false)
                    } else {
                        EmptyStateView(
                            title: L10n.selectArtwork,
                            subtitle: L10n.pixivActivityOpenHint,
                            systemImage: "photo"
                        )
                    }
                case .novel:
                    NovelDetailView(store: store)
                }
            }
            .os26SheetChrome(.detail)
        }
        .overlay(alignment: .bottom) {
            activityFeedbackOverlay
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: store.pixivActivityErrorMessage)
        .task(id: store.routeRefreshGeneration) {
            await store.refreshPixivActivityFeed()
        }
        .task(id: actionMessage) {
            await dismissActionMessageIfNeeded(actionMessage)
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if store.isLoadingPixivActivityFeed, store.pixivActivityItems.isEmpty {
            OS26LibraryLoadingView(title: L10n.loading, systemImage: PixivRoute.pixivActivity.systemImage)
        } else if store.pixivActivityItems.isEmpty {
            OS26LibraryUnavailableView(
                title: L10n.pixivActivityEmptyTitle,
                subtitle: store.pixivActivityErrorMessage ?? L10n.pixivActivityEmptyHint,
                systemImage: PixivRoute.pixivActivity.systemImage
            ) {
                retryButton
            }
        } else {
            NativePixivActivityListView(
                items: store.pixivActivityItems,
                layoutMode: effectiveActivityLayoutMode,
                rowHeight: 118,
                onNearContentEnd: loadMoreIfNeeded
            ) { item in
                if effectiveActivityLayoutMode.usesMasonry {
                    AnyView(PixivActivityMasonryCard(
                        item: item,
                        openActivityActor: { openActivityActor(item.actor) },
                        openWorkAuthor: { openActivityActor(item.target?.author) },
                        openWork: { openWork(for: item) },
                        openBookmarkTag: openBookmarkTag
                    ))
                } else {
                    AnyView(PixivActivityRow(
                        item: item,
                        openActivityActor: { openActivityActor(item.actor) },
                        openWorkAuthor: { openActivityActor(item.target?.author) },
                        openWork: { openWork(for: item) },
                        openBookmarkTag: openBookmarkTag
                    ))
                }
            }
            .nativeBottomTabContentSurface()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var webSessionState: some View {
        OS26LibraryUnavailableView(
            title: L10n.pixivActivityWebSessionRequiredTitle,
            subtitle: L10n.pixivActivityWebSessionRequiredHint,
            systemImage: "globe.badge.chevron.backward"
        ) {
            Button {
                store.isPixivWebSessionPresented = true
            } label: {
                Label(L10n.connectPixivWebSession, systemImage: "globe.badge.chevron.backward")
            }
            .os26GlassButton(prominent: true)
        }
    }

    @ViewBuilder
    private var titleActions: some View {
        if store.session != nil {
            OS26LibraryActionRail {
                Button {
                    Task { await refresh() }
                } label: {
                    Label(L10n.refresh, systemImage: "arrow.clockwise")
                }
                .os26GlassIconButton(prominent: store.isLoadingPixivActivityFeed)
                .disabled(store.isLoadingPixivActivityFeed || store.isLoadingMorePixivActivityFeed)
                .help(L10n.refresh)

                Menu {
                    if store.pixivWebSession?.isUsable != true {
                        Button {
                            store.isPixivWebSessionPresented = true
                        } label: {
                            Label(L10n.connectPixivWebSession, systemImage: "globe.badge.chevron.backward")
                        }

                        Divider()
                    }

                    Button {
                        openPixivActivityWebPage()
                    } label: {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }

                    Button {
                        copyPixivActivityLink()
                    } label: {
                        Label(L10n.copyLink, systemImage: "link")
                    }
                } label: {
                    Label(L10n.moreActions, systemImage: "ellipsis")
                }
                .os26GlassIconButton()
                .help(L10n.moreActions)
            }
            .controlSize(.small)
        }
    }

    private var retryButton: some View {
        Button {
            Task { await refresh() }
        } label: {
            Label(L10n.retry, systemImage: "arrow.clockwise")
        }
        .os26GlassButton(prominent: true)
    }

    @ViewBuilder
    private var activityFeedbackOverlay: some View {
        VStack(spacing: 8) {
            if store.isLoadingMorePixivActivityFeed {
                FloatingStatusBanner {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.pixivActivityLoadingMore)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let actionMessage {
                FloatingStatusBanner {
                    Text(actionMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let errorMessage = store.pixivActivityErrorMessage,
               store.pixivActivityItems.isEmpty == false {
                FloatingStatusBanner {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private var statusText: String {
        PixivActivityFeedPresentation.statusText(itemCount: store.pixivActivityItems.count)
    }

    private var effectiveActivityLayoutMode: PixivActivityLayoutMode {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? store.pixivActivityLayoutMode : .list
        #else
        .list
        #endif
    }

    private func refresh() async {
        await store.refreshPixivActivityFeed(force: true)
        if store.pixivActivityErrorMessage == nil, store.pixivActivityItems.isEmpty == false {
            showActionMessage(String(
                format: L10n.pixivActivityRefreshedFormat,
                store.pixivActivityItems.count
            ))
        }
    }

    private func loadMoreIfNeeded() {
        guard store.hasMorePixivActivityFeed,
              store.isLoadingPixivActivityFeed == false,
              store.isLoadingMorePixivActivityFeed == false else {
            return
        }
        Task { await store.loadMorePixivActivityFeed() }
    }

    private func openTarget(for item: PixivActivityItem) {
        guard let url = item.target?.url ?? actorURL(for: item.actor) else { return }
        Task {
            let message = await store.openPixivActivityTarget(url)
            showActionMessage(message)
        }
    }

    private func openActivityActor(_ actor: PixivActivityActor?) {
        guard let actor else { return }
        Task {
            if let message = await store.presentPixivActivityUserProfile(actor) {
                showActionMessage(message)
            }
        }
    }

    private func openWork(for item: PixivActivityItem) {
        guard let target = item.target else {
            openActivityActor(item.actor)
            return
        }
        guard let id = Int(target.id) else {
            openTarget(for: item)
            return
        }

        switch target.kind {
        case .artwork:
            Task {
                do {
                    _ = try await store.pixivActivityArtworkDetail(id: id)
                    withAnimation(.snappy(duration: 0.2)) {
                        presentedActivityDetail = .artwork(id)
                    }
                } catch {
                    showActionMessage(error.localizedDescription)
                }
            }
        case .novel:
            Task {
                do {
                    _ = try await store.pixivActivityNovelDetail(id: id)
                    withAnimation(.snappy(duration: 0.2)) {
                        presentedActivityDetail = .novel(id)
                    }
                } catch {
                    showActionMessage(error.localizedDescription)
                }
            }
        case .user:
            openActivityActor(PixivActivityActor(
                userID: id,
                name: target.title,
                avatarURL: target.thumbnailURL
            ))
        case .unknown:
            openTarget(for: item)
        }
    }

    private func openBookmarkTag(_ tag: PixivActivityBookmarkTag) {
        Task {
            let message = await store.openPixivActivityBookmarkTag(tag)
            showActionMessage(message)
        }
    }

    private func openPixivActivityWebPage() {
        guard let url = PixivWebURLBuilder.activityFeedURL() else { return }
        _ = PlatformWorkspace.open(url)
    }

    private func copyPixivActivityLink() {
        guard let url = PixivWebURLBuilder.activityFeedURL() else { return }
        PasteboardWriter.copy(url.absoluteString)
        showActionMessage(L10n.copied)
    }

    private func actorURL(for actor: PixivActivityActor?) -> URL? {
        guard let userID = actor?.userID else { return nil }
        return URL(string: "https://www.pixiv.net/users/\(userID)")
    }

    private func showActionMessage(_ message: String) {
        withAnimation(.snappy(duration: 0.18)) {
            actionMessage = message
        }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(nanoseconds: 2_200_000_000)
        guard Task.isCancelled == false, actionMessage == message else { return }
        await MainActor.run {
            withAnimation(.snappy(duration: 0.18)) {
                actionMessage = nil
            }
        }
    }
}

private enum PixivActivityDetailSheet: Identifiable {
    case artwork(Int)
    case novel(Int)

    var id: String {
        switch self {
        case .artwork(let id): "artwork-\(id)"
        case .novel(let id): "novel-\(id)"
        }
    }
}

private struct PixivActivityRow: View {
    let item: PixivActivityItem
    let openActivityActor: () -> Void
    let openWorkAuthor: () -> Void
    let openWork: () -> Void
    let openBookmarkTag: (PixivActivityBookmarkTag) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: openWork) {
                thumbnail
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Button(action: openActivityActor) {
                        Text(activityActorTitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)

                    Text(item.kind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.kind.tint)
                        .lineLimit(1)

                    if let occurredAt = item.occurredAt {
                        Text(PixivActivityFeedPresentation.compactTimeText(for: occurredAt))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Button(action: openWork) {
                    Text(workTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)

                HStack(spacing: 6) {
                    if authorTitle.isEmpty == false {
                        Button(action: openWorkAuthor) {
                            Text(authorTitle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    if let bookmarkTag = item.bookmarkTag {
                        Button {
                            openBookmarkTag(bookmarkTag)
                        } label: {
                            Text("#\(bookmarkTag.name)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(item.kind.tint)
                                .lineLimit(1)
                        }
                        .buttonStyle(.plain)
                    }

                    if authorTitle.isEmpty, item.bookmarkTag == nil {
                        Text(secondaryTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .keiGlass(18)
        .accessibilityLabel(accessibilityTitle)
    }

    private var activityActorTitle: String {
        PixivActivityFeedPresentation.activityActorTitle(for: item)
    }

    private var workTitle: String {
        PixivActivityFeedPresentation.masonryWorkTitle(for: item)
    }

    private var authorTitle: String {
        PixivActivityFeedPresentation.masonryAuthorTitle(for: item)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let url = item.target?.thumbnailURL ?? item.actor?.avatarURL {
            RemoteImageView(url: url, contentMode: .fill)
                .frame(width: 74, height: 74)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            Image(systemName: item.kind.systemImage)
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.kind.tint)
                .frame(width: 74, height: 74)
                .background(item.kind.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var primaryTitle: String {
        PixivActivityFeedPresentation.primaryTitle(for: item)
    }

    private var secondaryTitle: String {
        PixivActivityFeedPresentation.secondaryTitle(for: item)
    }

    private var accessibilityTitle: String {
        "\(item.kind.title), \(primaryTitle)"
    }
}

private struct PixivActivityMasonryCard: View {
    let item: PixivActivityItem
    let openActivityActor: () -> Void
    let openWorkAuthor: () -> Void
    let openWork: () -> Void
    let openBookmarkTag: (PixivActivityBookmarkTag) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: openWork) {
                ZStack {
                    thumbnailContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()

                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.18),
                            .black.opacity(0.70)
                        ],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }
            }
            .buttonStyle(.plain)

            topOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(9)

            metadataOverlay
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(11)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .keiGlass(18)
        .accessibilityLabel(accessibilityTitle)
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let url = item.target?.thumbnailURL ?? item.actor?.avatarURL {
            RemoteImageView(url: url, contentMode: .fill)
        } else {
            Image(systemName: item.kind.systemImage)
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(item.kind.tint)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(item.kind.tint.opacity(0.12))
        }
    }

    private var actorBadge: some View {
        HStack(spacing: 5) {
            if let url = item.actor?.avatarURL {
                RemoteImageView(url: url, contentMode: .fill)
                    .frame(width: 18, height: 18)
                    .clipShape(Circle())
            }

            Text(activityActorTitle)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(.black.opacity(0.32), in: Capsule())
    }

    private var eventBadge: some View {
        Image(systemName: item.kind.systemImage)
            .font(.caption2.weight(.bold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(item.kind.tint.opacity(0.98))
            .frame(width: 24, height: 24)
            .background(.black.opacity(0.30), in: Circle())
            .accessibilityLabel(item.kind.title)
    }

    private var topOverlay: some View {
        HStack(alignment: .top, spacing: 6) {
            Button(action: openActivityActor) {
                actorBadge
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            eventBadge

            if let occurredAt = item.occurredAt {
                Text(PixivActivityFeedPresentation.compactTimeText(for: occurredAt))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.30), in: Capsule())
            }
        }
    }

    private var metadataOverlay: some View {
        VStack(alignment: .leading, spacing: 3) {
            Button(action: openWork) {
                Text(workTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.32), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            if authorTitle.isEmpty == false {
                Button(action: openWorkAuthor) {
                    HStack(spacing: 4) {
                        Text(L10n.creator)
                            .foregroundStyle(.white.opacity(0.66))
                        Text(authorTitle)
                            .foregroundStyle(.white.opacity(0.86))
                    }
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.26), radius: 3, x: 0, y: 1)
                }
                .buttonStyle(.plain)
            }

            if let bookmarkTag = item.bookmarkTag {
                Button {
                    openBookmarkTag(bookmarkTag)
                } label: {
                    Text("#\(bookmarkTag.name)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(item.kind.tint.opacity(0.74), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var primaryTitle: String {
        PixivActivityFeedPresentation.primaryTitle(for: item)
    }

    private var accessibilityTitle: String {
        "\(item.kind.title), \(primaryTitle)"
    }

    private var workTitle: String {
        PixivActivityFeedPresentation.masonryWorkTitle(for: item)
    }

    private var activityActorTitle: String {
        PixivActivityFeedPresentation.activityActorTitle(for: item)
    }

    private var authorTitle: String {
        PixivActivityFeedPresentation.masonryAuthorTitle(for: item)
    }
}

private extension PixivActivityKind {
    var title: String {
        switch self {
        case .postedArtwork: L10n.pixivActivityPostedArtwork
        case .bookmarkedArtwork: L10n.pixivActivityBookmarkedArtwork
        case .followedUser: L10n.pixivActivityFollowedUser
        case .unknown: L10n.pixivActivityUnknown
        }
    }

    var systemImage: String {
        switch self {
        case .postedArtwork: "photo.on.rectangle"
        case .bookmarkedArtwork: "bookmark"
        case .followedUser: "person.crop.circle.badge.plus"
        case .unknown: "bolt.horizontal.circle"
        }
    }

    var tint: Color {
        switch self {
        case .postedArtwork: .blue
        case .bookmarkedArtwork: .pink
        case .followedUser: .green
        case .unknown: .secondary
        }
    }
}
