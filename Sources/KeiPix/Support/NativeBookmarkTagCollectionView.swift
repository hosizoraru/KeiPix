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
    var minimumItemWidth: CGFloat = 190
    var maximumItemWidth: CGFloat = 280
    var itemHeight: CGFloat = 76
    var emptyMessageHeight: CGFloat = 88
    var loadMoreHeight: CGFloat = 64
    var spacing: CGFloat = 12
    var sectionInsets = EdgeInsets(top: 14, leading: 18, bottom: 20, trailing: 18)

    func itemSize(for item: NativeBookmarkTagCollectionItem, containerWidth: CGFloat) -> CGSize {
        let availableWidth = max(containerWidth - sectionInsets.leading - sectionInsets.trailing, 1)
        if item.isFullWidth {
            return CGSize(width: availableWidth, height: fullWidthHeight(for: item))
        }
        return CGSize(width: itemWidth(in: availableWidth), height: itemHeight)
    }

    private func fullWidthHeight(for item: NativeBookmarkTagCollectionItem) -> CGFloat {
        switch item {
        case .emptyMessage:
            emptyMessageHeight
        case .loadMore:
            loadMoreHeight
        case .all, .unclassified, .tag:
            itemHeight
        }
    }

    private func itemWidth(in availableWidth: CGFloat) -> CGFloat {
        var columns = max(1, Int((availableWidth + spacing) / (minimumItemWidth + spacing)))
        var width = floor((availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))

        while width > maximumItemWidth, columns < 24 {
            columns += 1
            width = floor((availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        }

        if width < minimumItemWidth, columns > 1 {
            columns -= 1
            width = floor((availableWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))
        }

        return max(min(width, maximumItemWidth), min(minimumItemWidth, availableWidth))
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
        let collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.register(
            NativeBookmarkTagHostingCollectionCell.self,
            forCellWithReuseIdentifier: NativeBookmarkTagHostingCollectionCell.reuseIdentifier
        )
        collectionView.delegate = context.coordinator

        context.coordinator.configureDataSource(for: collectionView)
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)

        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateCollectionLayout(for: collectionView)
        context.coordinator.applySnapshot(to: collectionView)
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDelegateFlowLayout {
        var parent: NativeBookmarkTagCollectionView
        private var dataSource: UICollectionViewDiffableDataSource<Int, NativeBookmarkTagCollectionItem>?

        init(parent: NativeBookmarkTagCollectionView) {
            self.parent = parent
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
                flowLayout = UICollectionViewFlowLayout()
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
