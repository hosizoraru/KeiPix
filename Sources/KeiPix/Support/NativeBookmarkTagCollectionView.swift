import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum NativeBookmarkTagCollectionItem: Hashable, Identifiable {
    case all(count: Int?)
    case unclassified
    case tag(PixivBookmarkTag)
    case emptyMessage(String)
    case loadMore(isLoading: Bool)

    var id: String {
        switch self {
        case .all:
            "all"
        case .unclassified:
            "unclassified"
        case .tag(let tag):
            "tag-\(tag.name)"
        case .emptyMessage:
            "empty-message"
        case .loadMore:
            "load-more"
        }
    }

    var isFullWidth: Bool {
        switch self {
        case .emptyMessage, .loadMore:
            true
        case .all, .unclassified, .tag:
            false
        }
    }

    static func == (lhs: NativeBookmarkTagCollectionItem, rhs: NativeBookmarkTagCollectionItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

struct NativeBookmarkTagCollectionLayout: Equatable {
    var minimumTagItemWidth: CGFloat = 132
    var maximumTagItemWidth: CGFloat = 220
    var minimumShortcutItemWidth: CGFloat = 142
    var maximumShortcutItemWidth: CGFloat = 240
    var tagItemHeight: CGFloat = 52
    var shortcutItemHeight: CGFloat = 60
    var emptyMessageHeight: CGFloat = 104
    var loadMoreHeight: CGFloat = 64
    var fullWidthTagDisplayWidthThreshold: Double = 10.0
    var spacing: CGFloat = NativeCollectionLayoutMetrics.tagChips.itemSpacing
    var sectionInsets = NativeCollectionLayoutMetrics.tagChips.insets.edgeInsets

    func itemSize(for item: NativeBookmarkTagCollectionItem, containerWidth: CGFloat) -> CGSize {
        let availableWidth = max(containerWidth - sectionInsets.leading - sectionInsets.trailing, 1)
        if item.isFullWidth || usesFullWidthTagItem(for: item) {
            return CGSize(width: availableWidth, height: fullWidthHeight(for: item))
        }
        let metrics = itemMetrics(for: item)
        return CGSize(
            width: itemWidth(
                in: availableWidth,
                minimumWidth: metrics.minimumWidth,
                maximumWidth: metrics.maximumWidth
            ),
            height: metrics.height
        )
    }

    private func fullWidthHeight(for item: NativeBookmarkTagCollectionItem) -> CGFloat {
        switch item {
        case .emptyMessage:
            emptyMessageHeight
        case .loadMore:
            loadMoreHeight
        case .all, .unclassified, .tag:
            itemMetrics(for: item).height
        }
    }

    private func itemMetrics(for item: NativeBookmarkTagCollectionItem) -> ItemMetrics {
        switch item {
        case .all, .unclassified:
            ItemMetrics(
                minimumWidth: minimumShortcutItemWidth,
                maximumWidth: maximumShortcutItemWidth,
                height: shortcutItemHeight
            )
        case .tag:
            ItemMetrics(
                minimumWidth: minimumTagItemWidth,
                maximumWidth: maximumTagItemWidth,
                height: tagItemHeight
            )
        case .emptyMessage, .loadMore:
            ItemMetrics(
                minimumWidth: minimumTagItemWidth,
                maximumWidth: maximumTagItemWidth,
                height: fullWidthHeight(for: item)
            )
        }
    }

    private func itemWidth(in availableWidth: CGFloat, minimumWidth: CGFloat, maximumWidth: CGFloat) -> CGFloat {
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

    private func usesFullWidthTagItem(for item: NativeBookmarkTagCollectionItem) -> Bool {
        guard case .tag(let tag) = item else { return false }
        return displayWidthScore(for: tag.name) >= fullWidthTagDisplayWidthThreshold
    }

    private func displayWidthScore(for text: String) -> Double {
        text.reduce(0) { score, character in
            let scalar = character.unicodeScalars.first?.value ?? 0
            if scalar < 0x0080 {
                return score + 0.55
            }
            if (0xFF61...0xFF9F).contains(scalar) {
                return score + 0.65
            }
            return score + 1.0
        }
    }

    private struct ItemMetrics {
        let minimumWidth: CGFloat
        let maximumWidth: CGFloat
        let height: CGFloat
    }
}

/// Native grid container for bookmark tags.
///
/// The tag page keeps SwiftUI in charge of search, filtering, and the hosted
/// card content, while NSCollectionView / UICollectionView owns grid
/// virtualization and item reuse for large bookmark libraries.
@MainActor
struct NativeBookmarkTagCollectionView {
    let items: [NativeBookmarkTagCollectionItem]
    let layout: NativeBookmarkTagCollectionLayout
    let content: (NativeBookmarkTagCollectionItem) -> AnyView
}

#if os(macOS)
extension NativeBookmarkTagCollectionView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = NSCollectionView()

        collectionView.collectionViewLayout = NSCollectionViewFlowLayout()
        collectionView.register(
            NativeBookmarkTagHostingCollectionItem.self,
            forItemWithIdentifier: NativeBookmarkTagHostingCollectionItem.reuseIdentifier
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

    @MainActor
    final class Coordinator: NSObject, NSCollectionViewDelegateFlowLayout {
        var parent: NativeBookmarkTagCollectionView
        private var dataSource: NSCollectionViewDiffableDataSource<Int, NativeBookmarkTagCollectionItem>?

        init(parent: NativeBookmarkTagCollectionView) {
            self.parent = parent
        }

        func configureDataSource(for collectionView: NSCollectionView) {
            dataSource = NSCollectionViewDiffableDataSource<Int, NativeBookmarkTagCollectionItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.makeItem(
                        withIdentifier: NativeBookmarkTagHostingCollectionItem.reuseIdentifier,
                        for: indexPath
                      ) as? NativeBookmarkTagHostingCollectionItem else {
                    return NSCollectionViewItem()
                }
                cell.configure(with: parent.content(item))
                return cell
            }
        }

        func updateCollectionLayout(for collectionView: NSCollectionView) {
            let flowLayout: NSCollectionViewFlowLayout
            if let current = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
                flowLayout = current
            } else {
                flowLayout = NSCollectionViewFlowLayout()
                collectionView.collectionViewLayout = flowLayout
            }
            flowLayout.minimumInteritemSpacing = parent.layout.spacing
            flowLayout.minimumLineSpacing = parent.layout.spacing
            flowLayout.sectionInset = parent.layout.nsSectionInsets
            flowLayout.invalidateLayout()
        }

        func applySnapshot(to collectionView: NSCollectionView) {
            var snapshot = NSDiffableDataSourceSnapshot<Int, NativeBookmarkTagCollectionItem>()
            snapshot.appendSections([0])
            snapshot.appendItems(parent.items, toSection: 0)
            dataSource?.apply(snapshot, animatingDifferences: false) { [weak self, weak collectionView] in
                guard let self, let collectionView else { return }
                refreshVisibleHostedContent(in: collectionView)
            }
        }

        private func refreshVisibleHostedContent(in collectionView: NSCollectionView) {
            for indexPath in collectionView.indexPathsForVisibleItems() {
                guard indexPath.item < parent.items.count,
                      let item = collectionView.item(at: indexPath) as? NativeBookmarkTagHostingCollectionItem else {
                    continue
                }
                item.configure(with: parent.content(parent.items[indexPath.item]))
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
    }
}

private final class NativeBookmarkTagHostingCollectionItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("NativeBookmarkTagHostingCollectionItem")

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

private extension NativeBookmarkTagCollectionLayout {
    var nsSectionInsets: NSEdgeInsets {
        NSEdgeInsets(
            top: sectionInsets.top,
            left: sectionInsets.leading,
            bottom: sectionInsets.bottom,
            right: sectionInsets.trailing
        )
    }
}
#elseif os(iOS)
extension NativeBookmarkTagCollectionView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = NativeContentAwareCollectionView(
            frame: .zero,
            collectionViewLayout: NativeBookmarkTagLeftAlignedFlowLayout()
        )
        configureCollectionViewForBottomTabContent(collectionView)
        collectionView.register(
            NativeBookmarkTagHostingCollectionCell.self,
            forCellWithReuseIdentifier: NativeBookmarkTagHostingCollectionCell.reuseIdentifier
        )
        collectionView.delegate = context.coordinator
        collectionView.onHierarchyAvailable = { [weak coordinator = context.coordinator] collectionView in
            coordinator?.registerContentScrollViewIfNeeded(collectionView)
        }

        context.coordinator.configureDataSource(for: collectionView)
        context.coordinator.parent = self
        context.coordinator.registerContentScrollViewIfNeeded(collectionView)
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.registerContentScrollViewIfNeeded(collectionView)
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {
        var parent: NativeBookmarkTagCollectionView
        private var dataSource: UICollectionViewDiffableDataSource<Int, NativeBookmarkTagCollectionItem>?
        private let contentScrollRegistration = NativeContentScrollRegistration()

        init(parent: NativeBookmarkTagCollectionView) {
            self.parent = parent
        }

        deinit {
            let contentScrollRegistration = contentScrollRegistration
            Task { @MainActor in
                contentScrollRegistration.unregister()
            }
        }

        func registerContentScrollViewIfNeeded(_ collectionView: UICollectionView) {
            contentScrollRegistration.register(collectionView)
        }

        func configureDataSource(for collectionView: UICollectionView) {
            dataSource = UICollectionViewDiffableDataSource<Int, NativeBookmarkTagCollectionItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: NativeBookmarkTagHostingCollectionCell.reuseIdentifier,
                        for: indexPath
                      ) as? NativeBookmarkTagHostingCollectionCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: parent.content(item))
                return cell
            }
        }

        func updateCollectionLayout(for collectionView: UICollectionView) {
            let flowLayout: UICollectionViewFlowLayout
            if let current = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                flowLayout = current
            } else {
                flowLayout = NativeBookmarkTagLeftAlignedFlowLayout()
                collectionView.setCollectionViewLayout(flowLayout, animated: false)
            }
            flowLayout.minimumInteritemSpacing = parent.layout.spacing
            flowLayout.minimumLineSpacing = parent.layout.spacing
            flowLayout.sectionInset = parent.layout.uiSectionInsets
            flowLayout.invalidateLayout()
        }

        func applySnapshot(to collectionView: UICollectionView) {
            var snapshot = NSDiffableDataSourceSnapshot<Int, NativeBookmarkTagCollectionItem>()
            snapshot.appendSections([0])
            snapshot.appendItems(parent.items, toSection: 0)
            dataSource?.apply(snapshot, animatingDifferences: false) { [weak self, weak collectionView] in
                guard let self, let collectionView else { return }
                refreshVisibleHostedContent(in: collectionView)
            }
        }

        private func refreshVisibleHostedContent(in collectionView: UICollectionView) {
            for indexPath in collectionView.indexPathsForVisibleItems {
                guard indexPath.item < parent.items.count,
                      let cell = collectionView.cellForItem(at: indexPath) as? NativeBookmarkTagHostingCollectionCell else {
                    continue
                }
                cell.configure(with: parent.content(parent.items[indexPath.item]))
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
    }
}

private final class NativeBookmarkTagLeftAlignedFlowLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        guard let copiedAttributes = super.layoutAttributesForElements(in: rect)?.map({
            $0.copy() as? UICollectionViewLayoutAttributes
        }) else {
            return nil
        }

        var left = sectionInset.left
        var rowMaxY: CGFloat = -1
        for attributes in copiedAttributes where attributes?.representedElementCategory == .cell {
            guard let attributes else { continue }
            if attributes.frame.minY >= rowMaxY {
                left = sectionInset.left
            }
            attributes.frame.origin.x = left
            left += attributes.frame.width + minimumInteritemSpacing
            rowMaxY = max(rowMaxY, attributes.frame.maxY)
        }
        return copiedAttributes.compactMap { $0 }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        true
    }
}

private final class NativeBookmarkTagHostingCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "NativeBookmarkTagHostingCollectionCell"

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

private extension NativeBookmarkTagCollectionLayout {
    var uiSectionInsets: UIEdgeInsets {
        UIEdgeInsets(
            top: sectionInsets.top,
            left: sectionInsets.leading,
            bottom: sectionInsets.bottom,
            right: sectionInsets.trailing
        )
    }
}
#endif
