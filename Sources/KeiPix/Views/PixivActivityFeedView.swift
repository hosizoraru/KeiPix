import SwiftUI
#if os(iOS)
import UIKit
#endif

struct PixivActivityFeedView: View {
    @Bindable var store: KeiPixStore
    @State private var actionMessage: String?

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
                    AnyView(PixivActivityMasonryCard(item: item, openTarget: { openTarget(for: item) }))
                } else {
                    AnyView(PixivActivityRow(item: item, openTarget: { openTarget(for: item) }))
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

private struct PixivActivityRow: View {
    let item: PixivActivityItem
    let openTarget: () -> Void

    var body: some View {
        Button(action: openTarget) {
            HStack(alignment: .top, spacing: 12) {
                thumbnail

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(item.kind.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(item.kind.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(item.kind.tint.opacity(0.14), in: Capsule())

                        if let occurredAt = item.occurredAt {
                            Text(occurredAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    Text(primaryTitle)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(secondaryTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
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
        }
        .buttonStyle(.plain)
        .keiGlass(18)
        .accessibilityLabel(accessibilityTitle)
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
    let openTarget: () -> Void

    var body: some View {
        Button(action: openTarget) {
            VStack(alignment: .leading, spacing: 10) {
                thumbnail

                VStack(alignment: .leading, spacing: 6) {
                    Text(primaryTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(secondaryTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiGlass(18)
        .accessibilityLabel(accessibilityTitle)
    }

    private var thumbnail: some View {
        ZStack(alignment: .topLeading) {
            thumbnailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            kindBadge
                .padding(8)

            if let occurredAt = item.occurredAt {
                Text(occurredAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(8)
            }
        }
        .aspectRatio(thumbnailAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
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

    private var kindBadge: some View {
        Text(item.kind.title)
            .font(.caption2.weight(.bold))
            .foregroundStyle(item.kind.tint)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
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

    private var thumbnailAspectRatio: CGFloat {
        if item.target?.thumbnailURL != nil {
            return 1.43
        }
        if item.actor?.avatarURL != nil || item.kind == .followedUser {
            return 1.61
        }
        return 1.72
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
