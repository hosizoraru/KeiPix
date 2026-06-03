import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct NativeAdaptiveGridCollectionLayout: Equatable {
    var minimumItemWidth: CGFloat
    var maximumItemWidth: CGFloat
    var itemHeight: CGFloat
    var spacing: CGFloat = 14
    var sectionInsets = EdgeInsets(top: 18, leading: 18, bottom: 20, trailing: 18)

    func itemSize(containerWidth: CGFloat) -> CGSize {
        let availableWidth = max(containerWidth - sectionInsets.leading - sectionInsets.trailing, 1)
        return CGSize(width: itemWidth(in: availableWidth), height: itemHeight)
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

/// Shared native adaptive grid for P2 card surfaces.
///
/// SwiftUI remains the source of truth for filtering, actions, menus, and row
/// content. AppKit/UIKit owns scrolling, reuse, and adaptive item sizing.
@MainActor
struct NativeAdaptiveGridCollectionView<Item: Hashable> {
    let items: [Item]
    let layout: NativeAdaptiveGridCollectionLayout
    let content: (Item) -> AnyView
}

#if os(macOS)
extension NativeAdaptiveGridCollectionView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let collectionView = NSCollectionView()

        collectionView.collectionViewLayout = NSCollectionViewFlowLayout()
        collectionView.register(
            NativeAdaptiveGridHostingCollectionItem.self,
            forItemWithIdentifier: NativeAdaptiveGridHostingCollectionItem.reuseIdentifier
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
        var parent: NativeAdaptiveGridCollectionView
        private var dataSource: NSCollectionViewDiffableDataSource<Int, Item>?

        init(parent: NativeAdaptiveGridCollectionView) {
            self.parent = parent
        }

        func configureDataSource(for collectionView: NSCollectionView) {
            dataSource = NSCollectionViewDiffableDataSource<Int, Item>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.makeItem(
                        withIdentifier: NativeAdaptiveGridHostingCollectionItem.reuseIdentifier,
                        for: indexPath
                      ) as? NativeAdaptiveGridHostingCollectionItem else {
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
            var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
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
                      let item = collectionView.item(at: indexPath) as? NativeAdaptiveGridHostingCollectionItem else {
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
            parent.layout.itemSize(
                containerWidth: collectionView.enclosingScrollView?.contentSize.width ?? collectionView.bounds.width
            )
        }
    }
}

private final class NativeAdaptiveGridHostingCollectionItem: NSCollectionViewItem {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("NativeAdaptiveGridHostingCollectionItem")

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

private extension NativeAdaptiveGridCollectionLayout {
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
extension NativeAdaptiveGridCollectionView: UIViewRepresentable {
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
            NativeAdaptiveGridHostingCollectionCell.self,
            forCellWithReuseIdentifier: NativeAdaptiveGridHostingCollectionCell.reuseIdentifier
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
        var parent: NativeAdaptiveGridCollectionView
        private var dataSource: UICollectionViewDiffableDataSource<Int, Item>?

        init(parent: NativeAdaptiveGridCollectionView) {
            self.parent = parent
        }

        func configureDataSource(for collectionView: UICollectionView) {
            dataSource = UICollectionViewDiffableDataSource<Int, Item>(
                collectionView: collectionView
            ) { [weak self] collectionView, indexPath, item in
                guard let self,
                      let cell = collectionView.dequeueReusableCell(
                        withReuseIdentifier: NativeAdaptiveGridHostingCollectionCell.reuseIdentifier,
                        for: indexPath
                      ) as? NativeAdaptiveGridHostingCollectionCell else {
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
            var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
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
                      let cell = collectionView.cellForItem(at: indexPath) as? NativeAdaptiveGridHostingCollectionCell else {
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
            parent.layout.itemSize(containerWidth: collectionView.bounds.width)
        }
    }
}

private final class NativeAdaptiveGridHostingCollectionCell: UICollectionViewCell {
    static let reuseIdentifier = "NativeAdaptiveGridHostingCollectionCell"

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

private extension NativeAdaptiveGridCollectionLayout {
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
