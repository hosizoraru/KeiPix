import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum NativeCreatorPreviewCollectionItem: Hashable, Identifiable {
    case preview(PixivUserPreview)
    case artwork(PixivArtwork)
    case loadMore

    var id: String {
        switch self {
        case .preview(let preview):
            "creator-\(preview.user.id)"
        case .artwork(let artwork):
            "artwork-\(artwork.id)"
        case .loadMore:
            "load-more"
        }
    }

    var isFullWidth: Bool {
        if case .loadMore = self {
            return true
        }
        return false
    }

    static func == (lhs: NativeCreatorPreviewCollectionItem, rhs: NativeCreatorPreviewCollectionItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum NativeCreatorPreviewCollectionLayout: Equatable {
    case auto
    case single
    case twoUp
    case horizontalShelf(itemWidth: CGFloat, itemHeight: CGFloat)

    init(mode: CreatorListLayoutMode) {
        switch mode {
        case .auto:
            self = .auto
        case .single:
            self = .single
        case .twoUp:
            self = .twoUp
        }
    }

    var interitemSpacing: CGFloat { 14 }

    var lineSpacing: CGFloat { 14 }

    var sectionInsets: EdgeInsets {
        if case .horizontalShelf = self {
            return EdgeInsets(top: 2, leading: 1, bottom: 2, trailing: 1)
        }
        return EdgeInsets(top: 14, leading: 18, bottom: 20, trailing: 18)
    }

    var viewportHeight: CGFloat? {
        guard case .horizontalShelf(_, let itemHeight) = self else { return nil }
        let insets = sectionInsets
        return itemHeight + insets.top + insets.bottom
    }

    func itemSize(for item: NativeCreatorPreviewCollectionItem, containerWidth: CGFloat) -> CGSize {
        if case .horizontalShelf(let itemWidth, let itemHeight) = self {
            return CGSize(width: itemWidth, height: itemHeight)
        }

        let insets = sectionInsets
        let availableWidth = max(containerWidth - insets.leading - insets.trailing, 1)

        if item.isFullWidth {
            return CGSize(width: availableWidth, height: 160)
        }

        let width = itemWidth(in: availableWidth)
        return CGSize(width: width, height: itemHeight(forWidth: width))
    }

    private func itemWidth(in availableWidth: CGFloat) -> CGFloat {
        switch self {
        case .single:
            return availableWidth
        case .twoUp:
            return max((availableWidth - interitemSpacing) / 2, 300)
        case .auto:
            let minimumWidth: CGFloat = 300
            let spacing = interitemSpacing
            let columns = max(1, Int((availableWidth + spacing) / (minimumWidth + spacing)))
            return floor((availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        case .horizontalShelf(let itemWidth, _):
            return itemWidth
        }
    }

    private func itemHeight(forWidth width: CGFloat) -> CGFloat {
        switch self {
        case .single:
            return 342
        case .auto, .twoUp:
            let previewHeight = max(width / 2.4, 118)
            return 54 + previewHeight + 28 + 28 + 36 + 28
        case .horizontalShelf(_, let itemHeight):
            return itemHeight
        }
    }
}

/// Native collection container for creator preview surfaces.
///
/// P2 keeps the creator card content hosted in SwiftUI, but moves the
/// high-density grid, reuse, and layout invalidation into AppKit/UIKit.
@MainActor
struct NativeCreatorPreviewCollectionView {
    let items: [NativeCreatorPreviewCollectionItem]
    let layout: NativeCreatorPreviewCollectionLayout
    let content: (NativeCreatorPreviewCollectionItem) -> AnyView
}

#if os(macOS)
extension NativeCreatorPreviewCollectionView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = NSCollectionView()

        collectionView.collectionViewLayout = NSCollectionViewFlowLayout()
        collectionView.register(
            NativeCreatorPreviewHostingCollectionItem.self,
            forItemWithIdentifier: NativeCreatorPreviewHostingCollectionItem.reuseIdentifier
        )
        collectionView.delegate = context.coordinator
        collectionView.isSelectable = false
        collectionView.backgroundColors = [.clear]
        configureScrollBehavior(for: scrollView, collectionView: collectionView)

        scrollView.documentView = collectionView
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay

        context.coordinator.configureDataSource(for: collectionView)
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let collectionView = scrollView.documentView as? NSCollectionView else { return }
        configureScrollBehavior(for: scrollView, collectionView: collectionView)
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)
    }

    private func configureScrollBehavior(for scrollView: NSScrollView, collectionView: NSCollectionView) {
        collectionView.autoresizingMask = layout.scrollDirection == .horizontal ? [.height] : [.width]
        scrollView.hasVerticalScroller = layout.scrollDirection == .vertical
        scrollView.hasHorizontalScroller = layout.scrollDirection == .horizontal
        scrollView.verticalScrollElasticity = layout.scrollDirection == .vertical ? .allowed : .none
        scrollView.horizontalScrollElasticity = layout.scrollDirection == .horizontal ? .allowed : .none
    }

    @MainActor
    final class Coordinator: NSObject, NSCollectionViewDelegateFlowLayout {
        var parent: NativeCreatorPreviewCollectionView
        private var dataSource: NSCollectionViewDiffableDataSource<Int, NativeCreatorPreviewCollectionItem>?

        init(parent: NativeCreatorPreviewCollectionView) {
            self.parent = parent
        }

        func configureDataSource(for collectionView: NSCollectionView) {
            dataSource = NSCollectionViewDiffableDataSource<Int, NativeCreatorPreviewCollectionItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.makeItem(
                        withIdentifier: NativeCreatorPreviewHostingCollectionItem.reuseIdentifier,
                        for: indexPath
                      ) as? NativeCreatorPreviewHostingCollectionItem else {
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
            flowLayout.minimumInteritemSpacing = parent.layout.interitemSpacing
            flowLayout.minimumLineSpacing = parent.layout.lineSpacing
            flowLayout.sectionInset = parent.layout.nsSectionInsets
            flowLayout.scrollDirection = parent.layout.nsScrollDirection
            flowLayout.invalidateLayout()
        }

        func applySnapshot(to collectionView: NSCollectionView) {
            var snapshot = NSDiffableDataSourceSnapshot<Int, NativeCreatorPreviewCollectionItem>()
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
                      let item = collectionView.item(at: indexPath) as? NativeCreatorPreviewHostingCollectionItem else {
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

private final class NativeCreatorPreviewHostingCollectionItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("NativeCreatorPreviewHostingCollectionItem")

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

private extension NativeCreatorPreviewCollectionLayout {
    var scrollDirection: NativeCreatorPreviewCollectionScrollDirection {
        if case .horizontalShelf = self {
            return .horizontal
        }
        return .vertical
    }

    var nsSectionInsets: NSEdgeInsets {
        let insets = sectionInsets
        return NSEdgeInsets(
            top: insets.top,
            left: insets.leading,
            bottom: insets.bottom,
            right: insets.trailing
        )
    }

    var nsScrollDirection: NSCollectionView.ScrollDirection {
        scrollDirection == .horizontal ? .horizontal : .vertical
    }
}
#elseif os(iOS)
extension NativeCreatorPreviewCollectionView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        collectionView.backgroundColor = .clear
        configureScrollBehavior(for: collectionView)
        collectionView.register(
            NativeCreatorPreviewHostingCollectionCell.self,
            forCellWithReuseIdentifier: NativeCreatorPreviewHostingCollectionCell.reuseIdentifier
        )
        collectionView.delegate = context.coordinator

        context.coordinator.configureDataSource(for: collectionView)
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        configureScrollBehavior(for: collectionView)
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)
    }

    private func configureScrollBehavior(for collectionView: UICollectionView) {
        collectionView.alwaysBounceVertical = layout.scrollDirection == .vertical
        collectionView.alwaysBounceHorizontal = layout.scrollDirection == .horizontal
        collectionView.showsVerticalScrollIndicator = layout.scrollDirection == .vertical
        collectionView.showsHorizontalScrollIndicator = layout.scrollDirection == .horizontal
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {
        var parent: NativeCreatorPreviewCollectionView
        private var dataSource: UICollectionViewDiffableDataSource<Int, NativeCreatorPreviewCollectionItem>?

        init(parent: NativeCreatorPreviewCollectionView) {
            self.parent = parent
        }

        func configureDataSource(for collectionView: UICollectionView) {
            dataSource = UICollectionViewDiffableDataSource<Int, NativeCreatorPreviewCollectionItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: NativeCreatorPreviewHostingCollectionCell.reuseIdentifier,
                        for: indexPath
                      ) as? NativeCreatorPreviewHostingCollectionCell else {
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
                flowLayout = UICollectionViewFlowLayout()
                collectionView.setCollectionViewLayout(flowLayout, animated: false)
            }
            flowLayout.minimumInteritemSpacing = parent.layout.interitemSpacing
            flowLayout.minimumLineSpacing = parent.layout.lineSpacing
            flowLayout.sectionInset = parent.layout.uiSectionInsets
            flowLayout.scrollDirection = parent.layout.uiScrollDirection
            flowLayout.invalidateLayout()
        }

        func applySnapshot(to collectionView: UICollectionView) {
            var snapshot = NSDiffableDataSourceSnapshot<Int, NativeCreatorPreviewCollectionItem>()
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
                      let cell = collectionView.cellForItem(at: indexPath) as? NativeCreatorPreviewHostingCollectionCell else {
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

private final class NativeCreatorPreviewHostingCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "NativeCreatorPreviewHostingCollectionCell"

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

private extension NativeCreatorPreviewCollectionLayout {
    var scrollDirection: NativeCreatorPreviewCollectionScrollDirection {
        if case .horizontalShelf = self {
            return .horizontal
        }
        return .vertical
    }

    var uiSectionInsets: UIEdgeInsets {
        let insets = sectionInsets
        return UIEdgeInsets(
            top: insets.top,
            left: insets.leading,
            bottom: insets.bottom,
            right: insets.trailing
        )
    }

    var uiScrollDirection: UICollectionView.ScrollDirection {
        scrollDirection == .horizontal ? .horizontal : .vertical
    }
}
#endif

private enum NativeCreatorPreviewCollectionScrollDirection {
    case vertical
    case horizontal
}
