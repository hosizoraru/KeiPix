import SwiftUI

enum NativeGalleryCollectionItem: Hashable, Identifiable {
    case empty
    case cachedStatus
    case popularPreview
    case artwork(PixivArtwork)
    case loadMore

    var id: String {
        switch self {
        case .empty:
            "empty"
        case .cachedStatus:
            "cached-status"
        case .popularPreview:
            "popular-preview"
        case .artwork(let artwork):
            "artwork-\(artwork.id)"
        case .loadMore:
            "load-more"
        }
    }

    var artworkID: Int? {
        guard case .artwork(let artwork) = self else { return nil }
        return artwork.id
    }

    var artworkAspectRatio: CGFloat {
        guard case .artwork(let artwork) = self else {
            return ArtworkMasonryPresentation.fallbackAspectRatio
        }
        return ArtworkMasonryPresentation(artwork: artwork).aspectRatio
    }

    var isFullWidth: Bool {
        switch self {
        case .empty, .cachedStatus, .popularPreview, .loadMore:
            true
        case .artwork:
            false
        }
    }

    static func == (lhs: NativeGalleryCollectionItem, rhs: NativeGalleryCollectionItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum NativeGalleryCollectionLayout: Equatable {
    case compactGrid(cardHeight: CGFloat, loadMoreHeight: CGFloat)
    case listRow(rowHeight: CGFloat, loadMoreHeight: CGFloat)
    case masonry(configuration: ArtworkMasonryLayoutConfiguration, loadMoreHeight: CGFloat)

    var interitemSpacing: CGFloat {
        switch self {
        case .compactGrid:
            12
        case .listRow:
            10
        case .masonry(let configuration, _):
            configuration.spacing
        }
    }

    var lineSpacing: CGFloat {
        interitemSpacing
    }

    var sectionInsets: EdgeInsets {
        EdgeInsets(top: 14, leading: 18, bottom: 20, trailing: 18)
    }

    func itemSize(for item: NativeGalleryCollectionItem, containerWidth: CGFloat) -> CGSize {
        let insets = sectionInsets
        let availableWidth = max(containerWidth - insets.leading - insets.trailing, 1)

        if item.isFullWidth {
            return CGSize(width: availableWidth, height: fullWidthHeight(for: item))
        }

        switch self {
        case .compactGrid(let cardHeight, _):
            return CGSize(width: compactGridItemWidth(in: availableWidth), height: cardHeight)
        case .listRow(let rowHeight, _):
            return CGSize(width: availableWidth, height: rowHeight)
        case .masonry:
            return CGSize(width: availableWidth, height: 1)
        }
    }

    fileprivate func fullWidthHeight(for item: NativeGalleryCollectionItem) -> CGFloat {
        switch item {
        case .empty:
            420
        case .cachedStatus:
            82
        case .popularPreview:
            270
        case .loadMore:
            switch self {
            case .compactGrid(_, let loadMoreHeight),
                 .listRow(_, let loadMoreHeight),
                 .masonry(_, let loadMoreHeight):
                loadMoreHeight
            }
        case .artwork:
            1
        }
    }

    fileprivate var usesMasonry: Bool {
        guard case .masonry = self else { return false }
        return true
    }

    fileprivate var masonryConfiguration: ArtworkMasonryLayoutConfiguration? {
        guard case .masonry(let configuration, _) = self else { return nil }
        return configuration
    }

    fileprivate func masonryElement(for item: NativeGalleryCollectionItem) -> ArtworkMasonryPlacement.Element {
        if item.isFullWidth {
            return .fullWidth(height: fullWidthHeight(for: item))
        }
        return .artwork(aspectRatio: item.artworkAspectRatio)
    }

    private func compactGridItemWidth(in availableWidth: CGFloat) -> CGFloat {
        let minimumWidth: CGFloat = 148
        let maximumWidth: CGFloat = 210
        let spacing = interitemSpacing
        var columns = max(1, Int((availableWidth + spacing) / (minimumWidth + spacing)))
        var width = floor((availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))

        while width > maximumWidth, columns < 24 {
            columns += 1
            width = floor((availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        }

        if width < minimumWidth, columns > 1 {
            columns -= 1
            width = floor((availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        }

        return max(min(width, maximumWidth), min(minimumWidth, availableWidth))
    }
}

private struct NativeGalleryLayoutItemFingerprint: Equatable {
    let id: String
    let artworkAspectRatio: CGFloat
    let isFullWidth: Bool
}

#if os(macOS)
import AppKit

struct NativeGalleryCollectionView: NSViewRepresentable {
    let items: [NativeGalleryCollectionItem]
    let layout: NativeGalleryCollectionLayout
    let highlightedArtworkIDs: Set<Int>
    let scrollToArtworkID: Int?
    let contentReloadToken: Int
    let onRefresh: (() async -> Void)?
    let content: (NativeGalleryCollectionItem) -> AnyView

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = NSCollectionView()

        collectionView.collectionViewLayout = context.coordinator.makeCollectionLayout()
        collectionView.register(
            NativeGalleryHostingCollectionItem.self,
            forItemWithIdentifier: NativeGalleryHostingCollectionItem.reuseIdentifier
        )
        collectionView.delegate = context.coordinator
        collectionView.isSelectable = false
        collectionView.backgroundColors = [.clear]
        collectionView.autoresizingMask = [.width]

        scrollView.documentView = collectionView
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed

        context.coordinator.configureDataSource(for: collectionView)
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let collectionView = scrollView.documentView as? NSCollectionView else { return }
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, NSCollectionViewDelegateFlowLayout {
        var parent: NativeGalleryCollectionView
        private var dataSource: NSCollectionViewDiffableDataSource<Int, NativeGalleryCollectionItem>?
        private var lastSnapshotItemIDs: [String] = []
        private var lastLayout: NativeGalleryCollectionLayout?
        private var lastLayoutFingerprint: [NativeGalleryLayoutItemFingerprint] = []
        private var lastLayoutContainerWidth: CGFloat = 0
        private var lastHighlightedArtworkIDs: Set<Int> = []
        private var lastContentReloadToken: Int?
        private var lastScrollTarget: Int?
        private let widthChangeTolerance: CGFloat = 0.5

        init(parent: NativeGalleryCollectionView) {
            self.parent = parent
        }

        func makeCollectionLayout() -> NSCollectionViewLayout {
            if parent.layout.usesMasonry {
                return NativeGalleryMasonryNSCollectionViewLayout()
            }
            return NSCollectionViewFlowLayout()
        }

        func updateCollectionLayout(for collectionView: NSCollectionView) {
            let layoutFingerprint = parent.layoutFingerprint
            let containerWidth = collectionView.enclosingScrollView?.contentSize.width ?? collectionView.bounds.width
            let layoutNeedsRefresh = lastLayout != parent.layout
                || lastLayoutFingerprint != layoutFingerprint
                || abs(lastLayoutContainerWidth - containerWidth) > widthChangeTolerance

            if parent.layout.usesMasonry {
                let masonryLayout: NativeGalleryMasonryNSCollectionViewLayout
                let layoutWasReplaced: Bool
                if let current = collectionView.collectionViewLayout as? NativeGalleryMasonryNSCollectionViewLayout {
                    masonryLayout = current
                    layoutWasReplaced = false
                } else {
                    masonryLayout = NativeGalleryMasonryNSCollectionViewLayout()
                    collectionView.collectionViewLayout = masonryLayout
                    layoutWasReplaced = true
                }
                if layoutWasReplaced || layoutNeedsRefresh {
                    masonryLayout.items = parent.items
                    masonryLayout.nativeLayout = parent.layout
                    masonryLayout.invalidateLayout()
                    rememberLayout(fingerprint: layoutFingerprint, containerWidth: containerWidth)
                }
                return
            }

            let flowLayout: NSCollectionViewFlowLayout
            let layoutWasReplaced: Bool
            if let current = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
                flowLayout = current
                layoutWasReplaced = false
            } else {
                flowLayout = NSCollectionViewFlowLayout()
                collectionView.collectionViewLayout = flowLayout
                layoutWasReplaced = true
            }
            if layoutWasReplaced || layoutNeedsRefresh {
                flowLayout.minimumInteritemSpacing = parent.layout.interitemSpacing
                flowLayout.minimumLineSpacing = parent.layout.lineSpacing
                flowLayout.sectionInset = parent.layout.nsSectionInsets
                flowLayout.invalidateLayout()
                rememberLayout(fingerprint: layoutFingerprint, containerWidth: containerWidth)
            }
        }

        func configureDataSource(for collectionView: NSCollectionView) {
            dataSource = NSCollectionViewDiffableDataSource<Int, NativeGalleryCollectionItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.makeItem(
                        withIdentifier: NativeGalleryHostingCollectionItem.reuseIdentifier,
                        for: indexPath
                      ) as? NativeGalleryHostingCollectionItem else {
                    return NSCollectionViewItem()
                }
                cell.configure(with: parent.content(item))
                return cell
            }
        }

        func applySnapshot(to collectionView: NSCollectionView) {
            let itemIDs = parent.itemIDs
            let itemsChanged = itemIDs != lastSnapshotItemIDs
            let contentChanged = lastContentReloadToken != parent.contentReloadToken
            let needsInitialSnapshot = dataSource?.snapshot().numberOfItems == 0

            guard needsInitialSnapshot || itemsChanged || contentChanged else {
                reloadHighlightDeltaIfNeeded(in: collectionView)
                scrollToSelectionIfNeeded(in: collectionView)
                return
            }

            var snapshot = NSDiffableDataSourceSnapshot<Int, NativeGalleryCollectionItem>()
            snapshot.appendSections([0])
            snapshot.appendItems(parent.items, toSection: 0)
            lastSnapshotItemIDs = itemIDs
            lastContentReloadToken = parent.contentReloadToken
            dataSource?.apply(snapshot, animatingDifferences: false) { [weak self, weak collectionView] in
                guard let self, let collectionView else { return }
                if contentChanged && itemsChanged == false && needsInitialSnapshot == false {
                    self.reconfigureVisibleItems(in: collectionView)
                }
                self.lastHighlightedArtworkIDs = self.parent.highlightedArtworkIDs
                self.scrollToSelectionIfNeeded(in: collectionView)
            }
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            layout collectionViewLayout: NSCollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> NSSize {
            guard indexPath.item < parent.items.count else { return .zero }
            return parent.layout.itemSize(
                for: parent.items[indexPath.item],
                containerWidth: collectionView.enclosingScrollView?.contentSize.width ?? collectionView.bounds.width
            )
        }

        private func scrollToSelectionIfNeeded(in collectionView: NSCollectionView) {
            guard let artworkID = parent.scrollToArtworkID,
                  let index = parent.items.firstIndex(where: { $0.artworkID == artworkID }) else {
                return
            }
            let indexPath = IndexPath(item: index, section: 0)
            if collectionView.indexPathsForVisibleItems().contains(indexPath) {
                lastScrollTarget = artworkID
                return
            }
            guard artworkID != lastScrollTarget else { return }
            lastScrollTarget = artworkID
            collectionView.scrollToItems(
                at: [indexPath],
                scrollPosition: .centeredVertically
            )
        }

        private func rememberLayout(
            fingerprint: [NativeGalleryLayoutItemFingerprint],
            containerWidth: CGFloat
        ) {
            lastLayout = parent.layout
            lastLayoutFingerprint = fingerprint
            lastLayoutContainerWidth = containerWidth
        }

        private func reloadHighlightDeltaIfNeeded(in collectionView: NSCollectionView) {
            let newHighlightedArtworkIDs = parent.highlightedArtworkIDs
            let changedArtworkIDs = lastHighlightedArtworkIDs.symmetricDifference(newHighlightedArtworkIDs)
            lastHighlightedArtworkIDs = newHighlightedArtworkIDs
            guard changedArtworkIDs.isEmpty == false else { return }

            let visibleIndexPaths = collectionView.indexPathsForVisibleItems()
            let changedIndexPaths = indexPaths(forArtworkIDs: changedArtworkIDs)
                .intersection(visibleIndexPaths)
            guard changedIndexPaths.isEmpty == false else { return }
            reconfigureItems(at: changedIndexPaths, in: collectionView)
        }

        private func reconfigureVisibleItems(in collectionView: NSCollectionView) {
            let visibleIndexPaths = collectionView.indexPathsForVisibleItems()
            guard visibleIndexPaths.isEmpty == false else { return }
            reconfigureItems(at: visibleIndexPaths, in: collectionView)
        }

        private func reconfigureItems(
            at indexPaths: Set<IndexPath>,
            in collectionView: NSCollectionView
        ) {
            for indexPath in indexPaths where indexPath.item < parent.items.count {
                guard let cell = collectionView.item(at: indexPath) as? NativeGalleryHostingCollectionItem else {
                    continue
                }
                cell.configure(with: parent.content(parent.items[indexPath.item]))
            }
        }

        private func indexPaths(forArtworkIDs artworkIDs: Set<Int>) -> Set<IndexPath> {
            Set(artworkIDs.compactMap { artworkID in
                parent.items.firstIndex { $0.artworkID == artworkID }
                    .map { IndexPath(item: $0, section: 0) }
            })
        }
    }
}

private final class NativeGalleryMasonryNSCollectionViewLayout: NSCollectionViewLayout {
    var items: [NativeGalleryCollectionItem] = []
    var nativeLayout: NativeGalleryCollectionLayout = .masonry(
        configuration: ArtworkMasonryLayoutConfiguration(),
        loadMoreHeight: 210
    )

    private var cachedAttributes: [IndexPath: NSCollectionViewLayoutAttributes] = [:]
    private var cachedContentSize: CGSize = .zero

    override var collectionViewContentSize: NSSize {
        cachedContentSize
    }

    override func prepare() {
        super.prepare()

        guard let collectionView else {
            cachedAttributes = [:]
            cachedContentSize = .zero
            return
        }

        let insets = nativeLayout.sectionInsets
        let containerWidth = max(
            collectionView.enclosingScrollView?.contentSize.width ?? collectionView.bounds.width,
            1
        )
        let availableWidth = max(containerWidth - insets.leading - insets.trailing, 1)
        let configuration = nativeLayout.masonryConfiguration ?? ArtworkMasonryLayoutConfiguration()
        let resolved = ArtworkMasonryPlacement.resolve(
            elements: items.map { nativeLayout.masonryElement(for: $0) },
            availableWidth: availableWidth,
            configuration: configuration
        )

        var attributes: [IndexPath: NSCollectionViewLayoutAttributes] = [:]
        attributes.reserveCapacity(resolved.frames.count)
        for (index, frame) in resolved.frames.enumerated() {
            let indexPath = IndexPath(item: index, section: 0)
            let itemAttributes = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
            itemAttributes.frame = frame.offsetBy(dx: insets.leading, dy: insets.top)
            attributes[indexPath] = itemAttributes
        }

        cachedAttributes = attributes
        cachedContentSize = CGSize(
            width: containerWidth,
            height: resolved.size.height + insets.top + insets.bottom
        )
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        cachedAttributes.values.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        cachedAttributes[indexPath]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        true
    }
}

private final class NativeGalleryHostingCollectionItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("NativeGalleryHostingCollectionItem")

    private var hostingView: NSHostingView<AnyView>?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func configure(with content: AnyView) {
        if let hostingView {
            hostingView.rootView = content
            return
        }

        let hostingView = NSHostingView(rootView: content)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: view.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        self.hostingView = hostingView
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingView?.rootView = AnyView(EmptyView())
    }
}

private extension NativeGalleryCollectionLayout {
    var nsSectionInsets: NSEdgeInsets {
        let insets = sectionInsets
        return NSEdgeInsets(
            top: insets.top,
            left: insets.leading,
            bottom: insets.bottom,
            right: insets.trailing
        )
    }
}
#elseif os(iOS)
import UIKit

struct NativeGalleryCollectionView: UIViewRepresentable {
    let items: [NativeGalleryCollectionItem]
    let layout: NativeGalleryCollectionLayout
    let highlightedArtworkIDs: Set<Int>
    let scrollToArtworkID: Int?
    let contentReloadToken: Int
    let onRefresh: (() async -> Void)?
    let content: (NativeGalleryCollectionItem) -> AnyView

    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: context.coordinator.makeCollectionLayout()
        )
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.register(
            NativeGalleryHostingCollectionCell.self,
            forCellWithReuseIdentifier: NativeGalleryHostingCollectionCell.reuseIdentifier
        )
        collectionView.delegate = context.coordinator

        context.coordinator.configureDataSource(for: collectionView)
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.configureRefreshControl(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.configureRefreshControl(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {
        var parent: NativeGalleryCollectionView
        private var dataSource: UICollectionViewDiffableDataSource<Int, NativeGalleryCollectionItem>?
        private var lastSnapshotItemIDs: [String] = []
        private var lastLayout: NativeGalleryCollectionLayout?
        private var lastLayoutFingerprint: [NativeGalleryLayoutItemFingerprint] = []
        private var lastLayoutContainerWidth: CGFloat = 0
        private var lastHighlightedArtworkIDs: Set<Int> = []
        private var lastContentReloadToken: Int?
        private var lastScrollTarget: Int?
        private let widthChangeTolerance: CGFloat = 0.5

        init(parent: NativeGalleryCollectionView) {
            self.parent = parent
        }

        func makeCollectionLayout() -> UICollectionViewLayout {
            if parent.layout.usesMasonry {
                return NativeGalleryMasonryUICollectionViewLayout()
            }
            return UICollectionViewFlowLayout()
        }

        func updateCollectionLayout(for collectionView: UICollectionView) {
            let layoutFingerprint = parent.layoutFingerprint
            let containerWidth = collectionView.bounds.width
            let layoutNeedsRefresh = lastLayout != parent.layout
                || lastLayoutFingerprint != layoutFingerprint
                || abs(lastLayoutContainerWidth - containerWidth) > widthChangeTolerance

            if parent.layout.usesMasonry {
                let masonryLayout: NativeGalleryMasonryUICollectionViewLayout
                let layoutWasReplaced: Bool
                if let current = collectionView.collectionViewLayout as? NativeGalleryMasonryUICollectionViewLayout {
                    masonryLayout = current
                    layoutWasReplaced = false
                } else {
                    masonryLayout = NativeGalleryMasonryUICollectionViewLayout()
                    collectionView.setCollectionViewLayout(masonryLayout, animated: false)
                    layoutWasReplaced = true
                }
                if layoutWasReplaced || layoutNeedsRefresh {
                    masonryLayout.items = parent.items
                    masonryLayout.nativeLayout = parent.layout
                    masonryLayout.invalidateLayout()
                    rememberLayout(fingerprint: layoutFingerprint, containerWidth: containerWidth)
                }
                return
            }

            let flowLayout: UICollectionViewFlowLayout
            let layoutWasReplaced: Bool
            if let current = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                flowLayout = current
                layoutWasReplaced = false
            } else {
                flowLayout = UICollectionViewFlowLayout()
                collectionView.setCollectionViewLayout(flowLayout, animated: false)
                layoutWasReplaced = true
            }
            if layoutWasReplaced || layoutNeedsRefresh {
                flowLayout.minimumInteritemSpacing = parent.layout.interitemSpacing
                flowLayout.minimumLineSpacing = parent.layout.lineSpacing
                flowLayout.sectionInset = parent.layout.uiSectionInsets
                flowLayout.invalidateLayout()
                rememberLayout(fingerprint: layoutFingerprint, containerWidth: containerWidth)
            }
        }

        func configureRefreshControl(for collectionView: UICollectionView) {
            guard parent.onRefresh != nil else {
                collectionView.refreshControl = nil
                return
            }

            if collectionView.refreshControl == nil {
                let refreshControl = UIRefreshControl()
                refreshControl.addTarget(self, action: #selector(refreshRequested(_:)), for: .valueChanged)
                collectionView.refreshControl = refreshControl
            }
        }

        @objc private func refreshRequested(_ sender: UIRefreshControl) {
            Task { @MainActor in
                await parent.onRefresh?()
                sender.endRefreshing()
            }
        }

        func configureDataSource(for collectionView: UICollectionView) {
            dataSource = UICollectionViewDiffableDataSource<Int, NativeGalleryCollectionItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: NativeGalleryHostingCollectionCell.reuseIdentifier,
                        for: indexPath
                      ) as? NativeGalleryHostingCollectionCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: parent.content(item))
                return cell
            }
        }

        func applySnapshot(to collectionView: UICollectionView) {
            let itemIDs = parent.itemIDs
            let itemsChanged = itemIDs != lastSnapshotItemIDs
            let contentChanged = lastContentReloadToken != parent.contentReloadToken
            let needsInitialSnapshot = dataSource?.snapshot().numberOfItems == 0

            guard needsInitialSnapshot || itemsChanged || contentChanged else {
                reloadHighlightDeltaIfNeeded(in: collectionView)
                scrollToSelectionIfNeeded(in: collectionView)
                return
            }

            var snapshot = NSDiffableDataSourceSnapshot<Int, NativeGalleryCollectionItem>()
            snapshot.appendSections([0])
            snapshot.appendItems(parent.items, toSection: 0)
            lastSnapshotItemIDs = itemIDs
            lastContentReloadToken = parent.contentReloadToken
            dataSource?.apply(snapshot, animatingDifferences: false) { [weak self, weak collectionView] in
                guard let self, let collectionView else { return }
                if contentChanged && itemsChanged == false && needsInitialSnapshot == false {
                    self.reconfigureVisibleItems(in: collectionView)
                }
                self.lastHighlightedArtworkIDs = self.parent.highlightedArtworkIDs
                self.scrollToSelectionIfNeeded(in: collectionView)
            }
        }

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            guard indexPath.item < parent.items.count else { return .zero }
            return parent.layout.itemSize(
                for: parent.items[indexPath.item],
                containerWidth: collectionView.bounds.width
            )
        }

        private func scrollToSelectionIfNeeded(in collectionView: UICollectionView) {
            guard let artworkID = parent.scrollToArtworkID,
                  let index = parent.items.firstIndex(where: { $0.artworkID == artworkID }) else {
                return
            }
            let indexPath = IndexPath(item: index, section: 0)
            if collectionView.indexPathsForVisibleItems.contains(indexPath) {
                lastScrollTarget = artworkID
                return
            }
            guard artworkID != lastScrollTarget else { return }
            lastScrollTarget = artworkID
            collectionView.scrollToItem(
                at: indexPath,
                at: .centeredVertically,
                animated: true
            )
        }

        private func rememberLayout(
            fingerprint: [NativeGalleryLayoutItemFingerprint],
            containerWidth: CGFloat
        ) {
            lastLayout = parent.layout
            lastLayoutFingerprint = fingerprint
            lastLayoutContainerWidth = containerWidth
        }

        private func reloadHighlightDeltaIfNeeded(in collectionView: UICollectionView) {
            let newHighlightedArtworkIDs = parent.highlightedArtworkIDs
            let changedArtworkIDs = lastHighlightedArtworkIDs.symmetricDifference(newHighlightedArtworkIDs)
            lastHighlightedArtworkIDs = newHighlightedArtworkIDs
            guard changedArtworkIDs.isEmpty == false else { return }

            let visibleIndexPaths = Set(collectionView.indexPathsForVisibleItems)
            let changedIndexPaths = indexPaths(forArtworkIDs: changedArtworkIDs)
                .intersection(visibleIndexPaths)
            guard changedIndexPaths.isEmpty == false else { return }
            reconfigureItems(at: changedIndexPaths, in: collectionView)
        }

        private func reconfigureVisibleItems(in collectionView: UICollectionView) {
            let visibleIndexPaths = Set(collectionView.indexPathsForVisibleItems)
            guard visibleIndexPaths.isEmpty == false else { return }
            reconfigureItems(at: visibleIndexPaths, in: collectionView)
        }

        private func reconfigureItems(
            at indexPaths: Set<IndexPath>,
            in collectionView: UICollectionView
        ) {
            for indexPath in indexPaths where indexPath.item < parent.items.count {
                guard let cell = collectionView.cellForItem(at: indexPath) as? NativeGalleryHostingCollectionCell else {
                    continue
                }
                cell.configure(with: parent.content(parent.items[indexPath.item]))
            }
        }

        private func indexPaths(forArtworkIDs artworkIDs: Set<Int>) -> Set<IndexPath> {
            Set(artworkIDs.compactMap { artworkID in
                parent.items.firstIndex { $0.artworkID == artworkID }
                    .map { IndexPath(item: $0, section: 0) }
            })
        }
    }
}

private final class NativeGalleryMasonryUICollectionViewLayout: UICollectionViewLayout {
    var items: [NativeGalleryCollectionItem] = []
    var nativeLayout: NativeGalleryCollectionLayout = .masonry(
        configuration: ArtworkMasonryLayoutConfiguration(),
        loadMoreHeight: 210
    )

    private var cachedAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var cachedContentSize: CGSize = .zero

    override var collectionViewContentSize: CGSize {
        cachedContentSize
    }

    override func prepare() {
        super.prepare()

        guard let collectionView else {
            cachedAttributes = [:]
            cachedContentSize = .zero
            return
        }

        let insets = nativeLayout.sectionInsets
        let containerWidth = max(collectionView.bounds.width, 1)
        let availableWidth = max(containerWidth - insets.leading - insets.trailing, 1)
        let configuration = nativeLayout.masonryConfiguration ?? ArtworkMasonryLayoutConfiguration()
        let resolved = ArtworkMasonryPlacement.resolve(
            elements: items.map { nativeLayout.masonryElement(for: $0) },
            availableWidth: availableWidth,
            configuration: configuration
        )

        var attributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
        attributes.reserveCapacity(resolved.frames.count)
        for (index, frame) in resolved.frames.enumerated() {
            let indexPath = IndexPath(item: index, section: 0)
            let itemAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            itemAttributes.frame = frame.offsetBy(dx: insets.leading, dy: insets.top)
            attributes[indexPath] = itemAttributes
        }

        cachedAttributes = attributes
        cachedContentSize = CGSize(
            width: containerWidth,
            height: resolved.size.height + insets.top + insets.bottom
        )
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cachedAttributes.values.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cachedAttributes[indexPath]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
}

private final class NativeGalleryHostingCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "NativeGalleryHostingCollectionCell"

    private var hostingController: UIHostingController<AnyView>?

    func configure(with content: AnyView) {
        if let hostingController {
            hostingController.rootView = content
            return
        }

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        self.hostingController = hostingController
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.rootView = AnyView(EmptyView())
    }
}

private extension NativeGalleryCollectionLayout {
    var uiSectionInsets: UIEdgeInsets {
        let insets = sectionInsets
        return UIEdgeInsets(
            top: insets.top,
            left: insets.leading,
            bottom: insets.bottom,
            right: insets.trailing
        )
    }
}
#endif

private extension NativeGalleryCollectionView {
    var itemIDs: [String] {
        items.map(\.id)
    }

    var layoutFingerprint: [NativeGalleryLayoutItemFingerprint] {
        items.map { item in
            NativeGalleryLayoutItemFingerprint(
                id: item.id,
                artworkAspectRatio: item.artworkAspectRatio,
                isFullWidth: item.isFullWidth
            )
        }
    }
}
