import SwiftUI

struct ArtworkSummaryView: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let pageIndex: Int
    let pageCount: Int
    @State private var isUserProfilePresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(artwork.title)
                    .font(.title2.weight(.semibold))
                    .lineLimit(3)
                    .textSelection(.enabled)

                if store.showContentBadges {
                    ArtworkContentBadgesView(badges: artwork.contentBadges)
                }

                Button {
                    isUserProfilePresented = true
                } label: {
                    HStack(spacing: 10) {
                    RemoteImageView(url: artwork.user.avatarURL)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 1) {
                        Text(artwork.user.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text("@\(artwork.user.account)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .help(L10n.openCreatorProfile)
                .sheet(isPresented: $isUserProfilePresented) {
                    UserProfileSheet(user: artwork.user, store: store)
                }
            }

            ArtworkActionStrip(artwork: artwork, store: store, pageIndex: pageIndex, pageCount: pageCount)
        }
        .padding(14)
        .keiPanel(18)
    }
}

private struct ArtworkActionStrip: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let pageIndex: Int
    let pageCount: Int

    @Environment(\.openWindow) private var openWindow
    @State private var isBookmarkEditorPresented = false
    @State private var actionMessage: String?

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    MetricView(title: L10n.views, value: artwork.totalView, systemImage: "eye")
                    MetricView(title: L10n.saves, value: artwork.totalBookmarks, systemImage: "bookmark")
                    MetricView(title: L10n.comments, value: artwork.totalComments, systemImage: "text.bubble")
                    MetricView(title: L10n.pages, value: pageCount, systemImage: "square.stack", detail: pageCount > 1 ? "\(pageIndex + 1) / \(pageCount)" : nil)
                }

                if let actionMessage {
                    Text(actionMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 10) {
                    Button {
                        isBookmarkEditorPresented = true
                    } label: {
                        Label(artwork.isBookmarked ? L10n.editBookmark : L10n.bookmark, systemImage: artwork.isBookmarked ? "bookmark.fill" : "bookmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.small)
                    .sheet(isPresented: $isBookmarkEditorPresented) {
                        BookmarkEditorView(artwork: artwork, store: store)
                    }

                    Button {
                        store.enqueueDownload(artwork)
                    } label: {
                        Label(L10n.download, systemImage: "arrow.down.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    if let url = artwork.pixivURL {
                        Menu {
                            ShareLink(item: url) {
                                Label(L10n.share, systemImage: "square.and.arrow.up")
                            }

                            Button {
                                PasteboardWriter.copy(url.absoluteString)
                            } label: {
                                Label(L10n.copyLink, systemImage: "link")
                            }

                            Button {
                                copyArtworkSummary()
                            } label: {
                                Label(L10n.copyArtworkSummary, systemImage: "doc.text")
                            }
                        } label: {
                            Label(L10n.share, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Link(destination: url) {
                            Label(L10n.openInPixiv, systemImage: "safari")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        store.prepareReaderWindow(for: artwork)
                        openWindow(id: "artwork-reader")
                    } label: {
                        Label(L10n.openReaderWindow, systemImage: "rectangle.inset.filled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Menu {
                        Button(L10n.muteArtwork) {
                            store.muteArtwork(artwork)
                        }
                        Button(L10n.muteCreator) {
                            store.muteUser(artwork.user)
                        }
                        if artwork.tags.isEmpty == false {
                            Menu(L10n.muteTag) {
                                ForEach(artwork.tags, id: \.self) { tag in
                                    Button("#\(tag.name)") {
                                        store.muteTag(tag)
                                    }
                                }
                            }
                        }
                    } label: {
                        Label(L10n.mute, systemImage: "eye.slash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }

    private func copyArtworkSummary() {
        PasteboardWriter.copy(artworkSummaryText)
        actionMessage = L10n.copiedArtworkSummary

        Task {
            try? await Task.sleep(for: .seconds(2))
            if actionMessage == L10n.copiedArtworkSummary {
                actionMessage = nil
            }
        }
    }

    private var artworkSummaryText: String {
        let url = artwork.pixivURL?.absoluteString ?? ""
        let tags = artwork.tags.map { "#\($0.name)" }.joined(separator: " ")
        let badges = artwork.contentBadges.map(\.title).joined(separator: ", ")

        return [
            artwork.title,
            "\(L10n.creator): \(artwork.user.name) (@\(artwork.user.account))",
            "\(L10n.artworkID): \(artwork.id)",
            "\(L10n.creatorID): \(artwork.user.id)",
            "\(L10n.pages): \(pageCount)",
            "\(L10n.views): \(artwork.totalView.formatted())",
            "\(L10n.saves): \(artwork.totalBookmarks.formatted())",
            "\(L10n.comments): \(artwork.totalComments.formatted())",
            badges.isEmpty ? nil : "\(L10n.contentRating): \(badges)",
            tags.isEmpty ? nil : "\(L10n.tags): \(tags)",
            url.isEmpty ? nil : "\(L10n.openInPixiv): \(url)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
    }
}

private struct MetricView: View {
    let title: String
    let value: Int
    let systemImage: String
    var detail: String?

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(detail ?? value.formatted())
                    .font(.headline)
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
