import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum NativeBrowsingHistoryCollectionItem: Hashable, Identifiable {
    case local(LocalArtworkHistoryItem)
    case pixiv(PixivArtwork)
    case loadMore

    var id: String {
        switch self {
        case .local(let item):
            "local-\(item.id)"
        case .pixiv(let artwork):
            "pixiv-\(artwork.id)"
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

    static func == (lhs: NativeBrowsingHistoryCollectionItem, rhs: NativeBrowsingHistoryCollectionItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum NativeBrowsingHistoryCollectionLayout: Equatable {
    case localCards
    case pixivCards

    var interitemSpacing: CGFloat { 14 }

    var lineSpacing: CGFloat { 14 }

    var sectionInsets: EdgeInsets {
        EdgeInsets(top: 18, leading: 18, bottom: 20, trailing: 18)
    }

    func itemSize(for item: NativeBrowsingHistoryCollectionItem, containerWidth: CGFloat) -> CGSize {
        let insets = sectionInsets
        let availableWidth = max(containerWidth - insets.leading - insets.trailing, 1)

        if item.isFullWidth {
            return CGSize(width: availableWidth, height: loadMoreHeight)
        }

        return CGSize(width: itemWidth(in: availableWidth), height: itemHeight)
    }

    private var itemHeight: CGFloat {
        switch self {
        case .localCards:
            244
        case .pixivCards:
            152
        }
    }

    private var loadMoreHeight: CGFloat { 132 }

    private var minimumItemWidth: CGFloat {
        switch self {
        case .localCards:
            170
        case .pixivCards:
            160
        }
    }

    private var maximumItemWidth: CGFloat {
        switch self {
        case .localCards:
            240
        case .pixivCards:
            220
        }
    }

    private func itemWidth(in availableWidth: CGFloat) -> CGFloat {
        let spacing = interitemSpacing
        let minimumWidth = minimumItemWidth
        let maximumWidth = maximumItemWidth
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

/// Native collection container for the history surfaces.
///
/// This P1 slice moves virtualization and layout invalidation to
/// NSCollectionView / UICollectionView while keeping the existing SwiftUI card
/// content as the source of behavior.
@MainActor
struct NativeBrowsingHistoryCollectionView {
    let items: [NativeBrowsingHistoryCollectionItem]
    let layout: NativeBrowsingHistoryCollectionLayout
    let content: (NativeBrowsingHistoryCollectionItem) -> AnyView
}

#if os(macOS)
extension NativeBrowsingHistoryCollectionView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = NSCollectionView()

        collectionView.collectionViewLayout = NSCollectionViewFlowLayout()
        collectionView.register(
            NativeBrowsingHistoryHostingCollectionItem.self,
            forItemWithIdentifier: NativeBrowsingHistoryHostingCollectionItem.reuseIdentifier
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
        var parent: NativeBrowsingHistoryCollectionView
        private var dataSource: NSCollectionViewDiffableDataSource<Int, NativeBrowsingHistoryCollectionItem>?

        init(parent: NativeBrowsingHistoryCollectionView) {
            self.parent = parent
        }

        func configureDataSource(for collectionView: NSCollectionView) {
            dataSource = NSCollectionViewDiffableDataSource<Int, NativeBrowsingHistoryCollectionItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.makeItem(
                        withIdentifier: NativeBrowsingHistoryHostingCollectionItem.reuseIdentifier,
                        for: indexPath
                      ) as? NativeBrowsingHistoryHostingCollectionItem else {
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
            flowLayout.invalidateLayout()
        }

        func applySnapshot(to collectionView: NSCollectionView) {
            var snapshot = NSDiffableDataSourceSnapshot<Int, NativeBrowsingHistoryCollectionItem>()
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
                      let item = collectionView.item(at: indexPath) as? NativeBrowsingHistoryHostingCollectionItem else {
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

private final class NativeBrowsingHistoryHostingCollectionItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("NativeBrowsingHistoryHostingCollectionItem")

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

private extension NativeBrowsingHistoryCollectionLayout {
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
extension NativeBrowsingHistoryCollectionView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let collectionView = NativeContentAwareCollectionView(
            frame: .zero,
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        configureCollectionViewForBottomTabContent(collectionView)
        collectionView.register(
            NativeBrowsingHistoryHostingCollectionCell.self,
            forCellWithReuseIdentifier: NativeBrowsingHistoryHostingCollectionCell.reuseIdentifier
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
        var parent: NativeBrowsingHistoryCollectionView
        private var dataSource: UICollectionViewDiffableDataSource<Int, NativeBrowsingHistoryCollectionItem>?
        private let contentScrollRegistration = NativeContentScrollRegistration()

        init(parent: NativeBrowsingHistoryCollectionView) {
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
            dataSource = UICollectionViewDiffableDataSource<Int, NativeBrowsingHistoryCollectionItem>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: NativeBrowsingHistoryHostingCollectionCell.reuseIdentifier,
                        for: indexPath
                      ) as? NativeBrowsingHistoryHostingCollectionCell else {
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
            flowLayout.invalidateLayout()
        }

        func applySnapshot(to collectionView: UICollectionView) {
            var snapshot = NSDiffableDataSourceSnapshot<Int, NativeBrowsingHistoryCollectionItem>()
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
                      let cell = collectionView.cellForItem(at: indexPath) as? NativeBrowsingHistoryHostingCollectionCell else {
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

private final class NativeBrowsingHistoryHostingCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "NativeBrowsingHistoryHostingCollectionCell"

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

private extension NativeBrowsingHistoryCollectionLayout {
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
