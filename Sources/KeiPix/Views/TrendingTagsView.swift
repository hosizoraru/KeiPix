import AppKit
import SwiftUI

struct TrendingTagsView: View {
    @Bindable var store: KeiPixStore
    @State private var tags: [PixivTrendingTag] = []
    @State private var thumbnailAspectRatios: [String: CGFloat] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var actionMessage: String?

    var body: some View {
        Group {
            if store.session == nil {
                EmptyStateView(title: L10n.signedOutTitle, subtitle: L10n.signedOutSubtitle, systemImage: "person.crop.circle.badge.exclamationmark")
            } else if isLoading {
                ProgressView(L10n.loading)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tags.isEmpty {
                ContentUnavailableView(L10n.noTrendingTags, systemImage: "number")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    TrendingTagMasonryLayout(spacing: 12) {
                        ForEach(tags) { tag in
                            let presentation = TrendingTagPresentation(tag: tag)
                            let aspectRatio = thumbnailAspectRatios[tag.id] ?? presentation.aspectRatio
                            TrendingTagCard(
                                tag: tag,
                                showTranslatedName: store.showTranslatedTags,
                                showContentBadges: store.showContentBadges,
                                search: { search(tag) },
                                selectArtwork: { store.selectedArtwork = tag.artwork },
                                mute: { store.requestDangerAction(AppDangerAction(kind: .muteTag(tag.pixivTag))) },
                                copied: { copiedText in
                                    showActionMessage(String(format: L10n.copiedKeywordFormat, copiedText))
                                },
                                imageLoaded: { aspectRatio in
                                    thumbnailAspectRatios[tag.id] = aspectRatio
                                }
                            )
                            .layoutValue(key: TrendingTagAspectRatioKey.self, value: aspectRatio)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
            }
        }
        .navigationTitle(L10n.trendingTags)
        .toolbar {
            if tags.isEmpty == false {
                ToolbarItem(placement: .status) {
                    resultCountBadge
                }
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let actionMessage {
                    FloatingStatusBanner {
                        Text(actionMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let errorMessage {
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
        .animation(.snappy(duration: 0.18), value: actionMessage)
        .animation(.snappy(duration: 0.18), value: errorMessage)
        .task(id: store.routeRefreshGeneration) {
            await load()
        }
    }

    private var resultCountBadge: some View {
        Label("\(tags.count.formatted()) \(L10n.results)", systemImage: "number")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
            }
    }

    private func load() async {
        guard store.session != nil else { return }
        isLoading = true
        errorMessage = nil
        thumbnailAspectRatios = [:]
        defer { isLoading = false }

        do {
            tags = try await store.trendingTags()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func search(_ tag: PixivTrendingTag) {
        store.searchText = tag.name
        Task { await store.runSearch() }
    }

    private func showActionMessage(_ message: String) {
        actionMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if actionMessage == message {
                actionMessage = nil
            }
        }
    }
}

private struct TrendingTagCard: View {
    let tag: PixivTrendingTag
    let showTranslatedName: Bool
    let showContentBadges: Bool
    let search: () -> Void
    let selectArtwork: () -> Void
    let mute: () -> Void
    let copied: (String) -> Void
    let imageLoaded: (CGFloat) -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: search) {
            ZStack(alignment: .bottomLeading) {
                TrendingTagArtworkImage(url: tag.artwork.thumbnailURL, imageLoaded: imageLoaded)

                if showContentBadges {
                    ArtworkContentBadgesView(badges: tag.artwork.contentBadges, style: .overlay)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(tag.name)")
                        .font(.headline.weight(.semibold))
                        .lineLimit(1)
                        .trendingTagTextChip()

                    if let translatedName {
                        Text(translatedName)
                            .font(.caption)
                            .lineLimit(1)
                            .trendingTagTextChip(opacity: 0.34)
                    }
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.28), radius: 2, y: 1)
                .padding(8)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(isHovering ? 0.32 : 0), lineWidth: 1)
        }
        .shadow(color: .black.opacity(isHovering ? 0.16 : 0), radius: isHovering ? 12 : 0, y: isHovering ? 8 : 0)
        .animation(.snappy(duration: 0.16), value: isHovering)
        .onHover { isHovering = $0 }
        .help(tagHelp)
        .contextMenu {
            Button(L10n.searchTag, action: search)
            Button(L10n.selectArtwork, action: selectArtwork)

            Divider()

            Button(L10n.copyTag) {
                PasteboardWriter.copy(tag.name)
                copied("#\(tag.name)")
            }

            if let translatedName {
                Button(L10n.copyTranslatedTag) {
                    PasteboardWriter.copy(translatedName)
                    copied(translatedName)
                }
            }

            Divider()

            Button(L10n.muteTag, action: mute)
        }
    }

    private var translatedName: String? {
        guard showTranslatedName,
              let translatedName = tag.translatedName?.trimmingCharacters(in: .whitespacesAndNewlines),
              translatedName.isEmpty == false,
              translatedName.localizedCaseInsensitiveCompare(tag.name) != .orderedSame else {
            return nil
        }
        return translatedName
    }

    private var tagHelp: String {
        if let translatedName {
            return "#\(tag.name) / \(translatedName)"
        }
        return "#\(tag.name)"
    }
}

private extension View {
    func trendingTagTextChip(opacity: Double = 0.42) -> some View {
        padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.black.opacity(opacity), in: Capsule())
    }
}

private struct TrendingTagArtworkImage: View {
    let url: URL?
    let imageLoaded: (CGFloat) -> Void

    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    TrendingTagFillImageView(image: image)
                        .frame(width: ceil(proxy.size.width) + 2, height: ceil(proxy.size.height) + 2)
                        .clipped()
                        .allowsHitTesting(false)
                } else if failed {
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            image = nil
            failed = true
            return
        }

        image = nil
        failed = false

        do {
            let loadedImage = try await ImagePipeline.shared.image(for: url)
            image = loadedImage
            if let aspectRatio = ReaderPagePresentation.aspectRatio(from: loadedImage) {
                imageLoaded(aspectRatio)
            }
        } catch {
            failed = true
        }
    }
}

private struct TrendingTagFillImageView: NSViewRepresentable {
    let image: NSImage

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.contentsGravity = .resizeAspectFill
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.contentsGravity = .resizeAspectFill
        nsView.layer?.masksToBounds = true
        nsView.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        nsView.layer?.contentsScale = nsView.window?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        nsView.layer?.contents = cgImage(from: image)
    }

    private func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    }
}
