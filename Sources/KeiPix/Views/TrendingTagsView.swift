import AppKit
import SwiftUI

struct TrendingTagsView: View {
    @Bindable var store: KeiPixStore
    @State private var tags: [PixivTrendingTag] = []
    @State private var thumbnailAspectRatios: [String: CGFloat] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?

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
            if let errorMessage {
                FloatingStatusBanner {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
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
}

private struct TrendingTagCard: View {
    let tag: PixivTrendingTag
    let showTranslatedName: Bool
    let showContentBadges: Bool
    let search: () -> Void
    let selectArtwork: () -> Void
    let mute: () -> Void
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
            }

            if let translatedName {
                Button(L10n.copyTranslatedTag) {
                    PasteboardWriter.copy(translatedName)
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
    private let cornerRadius: CGFloat = 18

    let url: URL?
    let imageLoaded: (CGFloat) -> Void

    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        GeometryReader { proxy in
            if let image {
                ExactFillNSImageView(image: image, cornerRadius: cornerRadius)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.clear)
                    .overlay {
                        if failed {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                                .controlSize(.small)
                                .padding(8)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .task(id: url) {
            await load()
        }
    }

    private func load() async {
        guard let url else {
            failed = true
            image = nil
            return
        }

        failed = false
        image = nil

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

private struct ExactFillNSImageView: NSViewRepresentable {
    let image: NSImage
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> ExactFillNSImageContainer {
        let view = ExactFillNSImageContainer()
        view.image = image
        view.cornerRadius = cornerRadius
        return view
    }

    func updateNSView(_ nsView: ExactFillNSImageContainer, context: Context) {
        nsView.image = image
        nsView.cornerRadius = cornerRadius
    }
}

private final class ExactFillNSImageContainer: NSView {
    var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }

    var cornerRadius: CGFloat = 18 {
        didSet {
            needsDisplay = true
        }
    }

    override var isOpaque: Bool {
        false
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = false
        translatesAutoresizingMaskIntoConstraints = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }

        let imageSize = resolvedImageSize(for: image)
        guard imageSize.width > 0, imageSize.height > 0, bounds.width > 0, bounds.height > 0 else {
            return
        }

        NSGraphicsContext.current?.imageInterpolation = .high
        NSGraphicsContext.current?.shouldAntialias = true

        let clipPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        clipPath.addClip()

        let destination = bounds.insetBy(dx: -2, dy: -2)
        let source = sourceRect(for: imageSize, filling: destination.size)
        image.draw(in: destination, from: source, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private func resolvedImageSize(for image: NSImage) -> CGSize {
        if let representation = image.representations.max(by: { lhs, rhs in
            lhs.pixelsWide * lhs.pixelsHigh < rhs.pixelsWide * rhs.pixelsHigh
        }), representation.pixelsWide > 0, representation.pixelsHigh > 0 {
            return CGSize(width: representation.pixelsWide, height: representation.pixelsHigh)
        }
        return image.size
    }

    private func sourceRect(for imageSize: CGSize, filling destinationSize: CGSize) -> CGRect {
        let imageRatio = imageSize.width / imageSize.height
        let destinationRatio = destinationSize.width / destinationSize.height

        if imageRatio > destinationRatio {
            let width = imageSize.height * destinationRatio
            return CGRect(
                x: (imageSize.width - width) / 2,
                y: 0,
                width: width,
                height: imageSize.height
            )
        }

        let height = imageSize.width / destinationRatio
        return CGRect(
            x: 0,
            y: (imageSize.height - height) / 2,
            width: imageSize.width,
            height: height
        )
    }
}
