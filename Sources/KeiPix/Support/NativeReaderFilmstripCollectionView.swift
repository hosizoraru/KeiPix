import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@MainActor
struct NativeReaderFilmstripCollectionView {
    let items: [ReaderFilmstripPageItem]
    let selectedPageIndex: Int
    let presentation: ReaderFilmstripPresentation
    let selectPage: (Int) -> Void
    let content: (ReaderFilmstripPageItem, Bool) -> AnyView
}

#if os(macOS)
extension NativeReaderFilmstripCollectionView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = NSCollectionView()

        collectionView.collectionViewLayout = NSCollectionViewFlowLayout()
        collectionView.register(
            NativeReaderFilmstripHostingCollectionItem.self,
            forItemWithIdentifier: NativeReaderFilmstripHostingCollectionItem.reuseIdentifier
        )
        collectionView.delegate = context.coordinator
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.backgroundColors = [.clear]

        scrollView.documentView = collectionView
        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScrollElasticity = .allowed
        scrollView.horizontalScrollElasticity = .none

        context.coordinator.configureDataSource(for: collectionView)
        context.coordinator.parent = self
        context.coordinator.updateLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let collectionView = scrollView.documentView as? NSCollectionView else { return }
        context.coordinator.parent = self
        context.coordinator.updateLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)
        context.coordinator.scrollSelectedPageIntoView(in: collectionView)
    }

    @MainActor
    final class Coordinator: NSObject, NSCollectionViewDelegateFlowLayout {
        var parent: NativeReaderFilmstripCollectionView
        private var dataSource: NSCollectionViewDiffableDataSource<Int, ReaderFilmstripPageItem>?
        private var lastSnapshotItemIDs: [String] = []
        private var lastSelectedPageIndex: Int?
        private var lastItemSize: CGSize = .zero
        private var lastSpacing: CGFloat = 0

        init(parent: NativeReaderFilmstripCollectionView) {
            self.parent = parent
        }

        func configureDataSource(for collectionView: NSCollectionView) {
            dataSource = NSCollectionViewDiffableDataSource<Int, ReaderFilmstripPageItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.makeItem(
                        withIdentifier: NativeReaderFilmstripHostingCollectionItem.reuseIdentifier,
                        for: indexPath
                      ) as? NativeReaderFilmstripHostingCollectionItem else {
                    return NSCollectionViewItem()
                }
                cell.configure(with: parent.content(item, item.pageIndex == parent.selectedPageIndex))
                return cell
            }
        }

        func updateLayout(for collectionView: NSCollectionView) {
            let flowLayout: NSCollectionViewFlowLayout
            if let current = collectionView.collectionViewLayout as? NSCollectionViewFlowLayout {
                flowLayout = current
            } else {
                flowLayout = NSCollectionViewFlowLayout()
                collectionView.collectionViewLayout = flowLayout
            }

            guard lastItemSize != parent.presentation.itemSize
                    || lastSpacing != parent.presentation.itemSpacing else {
                return
            }

            flowLayout.itemSize = parent.presentation.itemSize
            flowLayout.minimumLineSpacing = parent.presentation.itemSpacing
            flowLayout.minimumInteritemSpacing = parent.presentation.itemSpacing
            flowLayout.sectionInset = NSEdgeInsets(top: 10, left: 0, bottom: 10, right: 0)
            flowLayout.scrollDirection = .vertical
            flowLayout.invalidateLayout()
            lastItemSize = parent.presentation.itemSize
            lastSpacing = parent.presentation.itemSpacing
        }

        func applySnapshot(to collectionView: NSCollectionView) {
            let itemIDs = parent.items.map(\.id)
            let itemsChanged = itemIDs != lastSnapshotItemIDs
            let selectionChanged = lastSelectedPageIndex != parent.selectedPageIndex
            let needsInitialSnapshot = dataSource?.snapshot().numberOfItems == 0

            guard needsInitialSnapshot || itemsChanged || selectionChanged else { return }

            var snapshot = NSDiffableDataSourceSnapshot<Int, ReaderFilmstripPageItem>()
            snapshot.appendSections([0])
            snapshot.appendItems(parent.items, toSection: 0)
            lastSnapshotItemIDs = itemIDs
            lastSelectedPageIndex = parent.selectedPageIndex
            dataSource?.apply(snapshot, animatingDifferences: false) { [weak self, weak collectionView] in
                guard let self, let collectionView else { return }
                refreshVisibleContent(in: collectionView)
                scrollSelectedPageIntoView(in: collectionView)
            }
        }

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            guard let indexPath = indexPaths.first,
                  let item = dataSource?.itemIdentifier(for: indexPath) else {
                return
            }
            selectPage(item.pageIndex)
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            layout collectionViewLayout: NSCollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> NSSize {
            parent.presentation.itemSize
        }

        func scrollSelectedPageIntoView(in collectionView: NSCollectionView) {
            guard let index = parent.items.firstIndex(where: { $0.pageIndex == parent.selectedPageIndex }) else { return }
            collectionView.scrollToItems(at: [IndexPath(item: index, section: 0)], scrollPosition: .centeredVertically)
        }

        private func refreshVisibleContent(in collectionView: NSCollectionView) {
            for indexPath in collectionView.indexPathsForVisibleItems() {
                guard let item = dataSource?.itemIdentifier(for: indexPath),
                      let cell = collectionView.item(at: indexPath) as? NativeReaderFilmstripHostingCollectionItem else {
                    continue
                }
                cell.configure(with: parent.content(item, item.pageIndex == parent.selectedPageIndex))
            }
        }

        private func selectPage(_ pageIndex: Int) {
            parent.selectPage(pageIndex)
        }
    }
}

private final class NativeReaderFilmstripHostingCollectionItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("NativeReaderFilmstripHostingCollectionItem")

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
#elseif os(iOS)
extension NativeReaderFilmstripCollectionView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: Self.makeLayout(presentation: presentation)
        )
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.alwaysBounceVertical = true
        collectionView.alwaysBounceHorizontal = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(
            NativeReaderFilmstripHostingCollectionCell.self,
            forCellWithReuseIdentifier: NativeReaderFilmstripHostingCollectionCell.reuseIdentifier
        )
        collectionView.delegate = context.coordinator

        context.coordinator.configureDataSource(for: collectionView)
        context.coordinator.parent = self
        context.coordinator.applySnapshot(to: collectionView)

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        collectionView.setCollectionViewLayout(Self.makeLayout(presentation: presentation), animated: false)
        context.coordinator.applySnapshot(to: collectionView)
        context.coordinator.scrollSelectedPageIntoView(in: collectionView)
    }

    private static func makeLayout(presentation: ReaderFilmstripPresentation) -> UICollectionViewCompositionalLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .absolute(presentation.itemSize.width),
            heightDimension: .absolute(presentation.itemSize.height)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .absolute(presentation.railWidth),
            heightDimension: .absolute(presentation.itemSize.height)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.contentInsets = NSDirectionalEdgeInsets(
            top: presentation.itemSpacing / 2,
            leading: (presentation.railWidth - presentation.itemSize.width) / 2,
            bottom: presentation.itemSpacing / 2,
            trailing: (presentation.railWidth - presentation.itemSize.width) / 2
        )
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = presentation.itemSpacing
        section.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)
        return UICollectionViewCompositionalLayout(section: section)
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDelegate {
        var parent: NativeReaderFilmstripCollectionView
        private var dataSource: UICollectionViewDiffableDataSource<Int, ReaderFilmstripPageItem>?
        private var lastSnapshotItemIDs: [String] = []
        private var lastSelectedPageIndex: Int?

        init(parent: NativeReaderFilmstripCollectionView) {
            self.parent = parent
        }

        func configureDataSource(for collectionView: UICollectionView) {
            dataSource = UICollectionViewDiffableDataSource<Int, ReaderFilmstripPageItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: NativeReaderFilmstripHostingCollectionCell.reuseIdentifier,
                        for: indexPath
                      ) as? NativeReaderFilmstripHostingCollectionCell else {
                    return UICollectionViewCell()
                }
                cell.configure(with: parent.content(item, item.pageIndex == parent.selectedPageIndex))
                return cell
            }
        }

        func applySnapshot(to collectionView: UICollectionView) {
            let itemIDs = parent.items.map(\.id)
            let itemsChanged = itemIDs != lastSnapshotItemIDs
            let selectionChanged = lastSelectedPageIndex != parent.selectedPageIndex
            let needsInitialSnapshot = dataSource?.snapshot().numberOfItems == 0

            guard needsInitialSnapshot || itemsChanged || selectionChanged else { return }

            var snapshot = NSDiffableDataSourceSnapshot<Int, ReaderFilmstripPageItem>()
            snapshot.appendSections([0])
            snapshot.appendItems(parent.items, toSection: 0)
            lastSnapshotItemIDs = itemIDs
            lastSelectedPageIndex = parent.selectedPageIndex
            let completion: () -> Void = { [weak self, weak collectionView] in
                guard let self, let collectionView else { return }
                refreshVisibleContent(in: collectionView)
                scrollSelectedPageIntoView(in: collectionView)
            }
            if needsInitialSnapshot || itemsChanged {
                dataSource?.applySnapshotUsingReloadData(snapshot, completion: completion)
            } else {
                dataSource?.apply(snapshot, animatingDifferences: false, completion: completion)
            }
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard let item = dataSource?.itemIdentifier(for: indexPath) else { return }
            selectPage(item.pageIndex)
        }

        func scrollSelectedPageIntoView(in collectionView: UICollectionView) {
            guard let index = parent.items.firstIndex(where: { $0.pageIndex == parent.selectedPageIndex }) else { return }
            collectionView.scrollToItem(
                at: IndexPath(item: index, section: 0),
                at: .centeredVertically,
                animated: false
            )
        }

        private func refreshVisibleContent(in collectionView: UICollectionView) {
            for indexPath in collectionView.indexPathsForVisibleItems {
                guard let item = dataSource?.itemIdentifier(for: indexPath),
                      let cell = collectionView.cellForItem(at: indexPath) as? NativeReaderFilmstripHostingCollectionCell else {
                    continue
                }
                cell.configure(with: parent.content(item, item.pageIndex == parent.selectedPageIndex))
            }
        }

        private func selectPage(_ pageIndex: Int) {
            parent.selectPage(pageIndex)
        }
    }
}

private final class NativeReaderFilmstripHostingCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "NativeReaderFilmstripHostingCollectionCell"

    private var hostingController: UIHostingController<AnyView>?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureAppearance()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureAppearance()
    }

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

    private func configureAppearance() {
        backgroundColor = .clear
        selectedBackgroundView = UIView()
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
    }
}
#endif
