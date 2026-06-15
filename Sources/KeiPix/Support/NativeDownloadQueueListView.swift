import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Native masonry collection container for the download queue.
///
/// AppKit/UIKit own virtualization, selection, keyboard handling, and masonry
/// placement while the current SwiftUI card remains the hosted content.
@MainActor
struct NativeDownloadQueueListView {
    let items: [ArtworkDownloadItem]
    let downloads: ArtworkDownloadStore
    @Binding var selectedItemID: UUID?
    let canOpen: @MainActor (ArtworkDownloadItem) -> Bool
    let open: @MainActor (ArtworkDownloadItem) -> Void
    let retry: @MainActor (ArtworkDownloadItem) -> Void
    let reveal: @MainActor (ArtworkDownloadItem) -> Void
    let quickLook: @MainActor (ArtworkDownloadItem) -> Void
    let copied: @MainActor () -> Void
    let cancel: @MainActor (ArtworkDownloadItem) -> Void
    let delete: @MainActor (ArtworkDownloadItem) -> Void

    @ViewBuilder
    fileprivate func row(for item: ArtworkDownloadItem) -> some View {
        DownloadQueueRow(
            item: item,
            downloads: downloads,
            canOpen: canOpen(item),
            isFocused: selectedItemID == item.id,
            open: { open(item) },
            retry: { retry(item) },
            reveal: { reveal(item) },
            quickLook: { quickLook(item) },
            copied: copied,
            cancel: { cancel(item) },
            delete: { delete(item) }
        )
    }

    fileprivate func quickLookSelectedItem() {
        guard let selectedItemID,
              let item = items.first(where: { $0.id == selectedItemID }) ?? items.first else {
            return
        }
        quickLook(item)
    }
}

#if os(macOS)
extension NativeDownloadQueueListView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true

        let collectionView = NativeDownloadQueueNSCollectionView()
        collectionView.collectionViewLayout = NativeDownloadQueueMasonryNSCollectionViewLayout()
        collectionView.backgroundColors = [.clear]
        collectionView.isSelectable = true
        collectionView.allowsMultipleSelection = false
        collectionView.autoresizingMask = [.width]
        collectionView.delegate = context.coordinator
        collectionView.dataSource = context.coordinator
        collectionView.register(
            NativeDownloadQueueCollectionItem.self,
            forItemWithIdentifier: NativeDownloadQueueCollectionItem.identifier
        )
        collectionView.onSpace = { [weak coordinator = context.coordinator] in
            coordinator?.parent.quickLookSelectedItem()
        }

        scrollView.documentView = collectionView
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        context.coordinator.collectionView = collectionView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let collectionView = context.coordinator.collectionView else { return }
        context.coordinator.updateMasonryLayout(for: collectionView)
        context.coordinator.applyItems(to: collectionView)
        context.coordinator.restoreSelection()
    }

    @MainActor
    final class Coordinator: NSObject, NSCollectionViewDataSource, NSCollectionViewDelegate {
        var parent: NativeDownloadQueueListView
        weak var collectionView: NSCollectionView?
        private var lastItemIDs: [UUID] = []

        init(parent: NativeDownloadQueueListView) {
            self.parent = parent
        }

        func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.items.count
        }

        func collectionView(
            _ collectionView: NSCollectionView,
            itemForRepresentedObjectAt indexPath: IndexPath
        ) -> NSCollectionViewItem {
            guard parent.items.indices.contains(indexPath.item),
                  let item = collectionView.makeItem(
                    withIdentifier: NativeDownloadQueueCollectionItem.identifier,
                    for: indexPath
                  ) as? NativeDownloadQueueCollectionItem else {
                return NSCollectionViewItem()
            }
            item.host(AnyView(parent.row(for: parent.items[indexPath.item])))
            return item
        }

        func updateMasonryLayout(for collectionView: NSCollectionView) {
            guard let layout = collectionView.collectionViewLayout as? NativeDownloadQueueMasonryNSCollectionViewLayout else {
                return
            }
            layout.items = parent.items
            layout.layoutKind = .regular
            layout.invalidateLayout()
        }

        func applyItems(to collectionView: NSCollectionView) {
            let itemIDs = parent.items.map(\.id)
            if itemIDs != lastItemIDs {
                lastItemIDs = itemIDs
                collectionView.reloadData()
                return
            }
            refreshVisibleItems(in: collectionView)
        }

        private func refreshVisibleItems(in collectionView: NSCollectionView) {
            for indexPath in collectionView.indexPathsForVisibleItems() {
                guard parent.items.indices.contains(indexPath.item),
                      let item = collectionView.item(at: indexPath) as? NativeDownloadQueueCollectionItem else {
                    continue
                }
                item.host(AnyView(parent.row(for: parent.items[indexPath.item])))
            }
        }

        func collectionView(_ collectionView: NSCollectionView, didSelectItemsAt indexPaths: Set<IndexPath>) {
            guard let indexPath = indexPaths.first,
                  parent.items.indices.contains(indexPath.item) else { return }
            parent.selectedItemID = parent.items[indexPath.item].id
            refreshVisibleItems(in: collectionView)
        }

        func restoreSelection() {
            guard let collectionView else { return }
            if let selectedItemID = parent.selectedItemID,
               let index = parent.items.firstIndex(where: { $0.id == selectedItemID }) {
                collectionView.selectItems(
                    at: [IndexPath(item: index, section: 0)],
                    scrollPosition: []
                )
            } else if parent.items.isEmpty == false {
                parent.selectedItemID = parent.items[0].id
                collectionView.selectItems(
                    at: [IndexPath(item: 0, section: 0)],
                    scrollPosition: []
                )
            } else {
                parent.selectedItemID = nil
                collectionView.deselectAll(nil)
            }
        }
    }
}

private final class NativeDownloadQueueNSCollectionView: NSCollectionView {
    var onSpace: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            onSpace?()
            return
        }
        super.keyDown(with: event)
    }
}

private final class NativeDownloadQueueMasonryNSCollectionViewLayout: NSCollectionViewLayout {
    var items: [ArtworkDownloadItem] = []
    var layoutKind: DownloadQueueMasonryLayoutKind = .regular

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

        let containerWidth = max(
            collectionView.enclosingScrollView?.contentSize.width ?? collectionView.bounds.width,
            1
        )
        let metrics = DownloadQueueMasonryPresentation.metrics(
            for: containerWidth,
            layoutKind: layoutKind
        )
        let itemWidth = metrics.itemWidth(for: containerWidth)
        let resolved = DownloadQueueMasonryPlacement.resolve(
            heights: items.map {
                DownloadQueueMasonryPresentation.cardHeight(
                    for: $0,
                    width: itemWidth,
                    layoutKind: layoutKind
                )
            },
            containerWidth: containerWidth,
            metrics: metrics
        )

        var attributes: [IndexPath: NSCollectionViewLayoutAttributes] = [:]
        attributes.reserveCapacity(resolved.frames.count)
        for (index, frame) in resolved.frames.enumerated() {
            let indexPath = IndexPath(item: index, section: 0)
            let itemAttributes = NSCollectionViewLayoutAttributes(forItemWith: indexPath)
            itemAttributes.frame = frame
            attributes[indexPath] = itemAttributes
        }

        cachedAttributes = attributes
        cachedContentSize = resolved.size
    }

    override func layoutAttributesForElements(in rect: NSRect) -> [NSCollectionViewLayoutAttributes] {
        cachedAttributes.values.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> NSCollectionViewLayoutAttributes? {
        cachedAttributes[indexPath]
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: NSRect) -> Bool {
        guard let collectionView else { return false }
        return NativeGalleryBoundsInvalidation.shouldInvalidate(
            oldSize: collectionView.bounds.size,
            newSize: newBounds.size
        )
    }
}

private final class NativeDownloadQueueCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("native-download-masonry-cell")

    private var hostingView: NSHostingView<AnyView>?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }

    func host(_ rootView: AnyView) {
        if let hostingView {
            hostingView.rootView = rootView
            return
        }

        let hostingView = NSHostingView(rootView: rootView)
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
}
#elseif os(iOS)
extension NativeDownloadQueueListView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = NativeDownloadQueueMasonryUICollectionViewLayout()
        let collectionView = NativeDownloadQueueCollectionView(frame: .zero, collectionViewLayout: layout)
        configureCollectionViewForBottomTabContent(collectionView)
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Coordinator.cellIdentifier)
        collectionView.onSpace = { [weak coordinator = context.coordinator] in
            coordinator?.parent.quickLookSelectedItem()
        }
        collectionView.onHierarchyAvailable = { [weak coordinator = context.coordinator] collectionView in
            coordinator?.registerContentScrollViewIfNeeded(collectionView)
        }
        context.coordinator.updateMasonryLayout(for: collectionView)
        context.coordinator.registerContentScrollViewIfNeeded(collectionView)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.registerContentScrollViewIfNeeded(collectionView)
        context.coordinator.updateMasonryLayout(for: collectionView)
        context.coordinator.applyItems(to: collectionView)
        context.coordinator.restoreSelection(in: collectionView)
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegate {
        static let cellIdentifier = "native-download-row-cell"

        var parent: NativeDownloadQueueListView
        private var lastItemIDs: [UUID] = []
        private let contentScrollRegistration = NativeContentScrollRegistration()

        init(parent: NativeDownloadQueueListView) {
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

        func updateMasonryLayout(for collectionView: UICollectionView) {
            guard let layout = collectionView.collectionViewLayout as? NativeDownloadQueueMasonryUICollectionViewLayout else {
                return
            }
            layout.items = parent.items
            layout.layoutKind = collectionView.traitCollection.horizontalSizeClass == .compact
                ? .compactPhone
                : .regular
            layout.invalidateLayout()
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.items.count
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.cellIdentifier,
                for: indexPath
            )
            guard parent.items.indices.contains(indexPath.item) else { return cell }
            let item = parent.items[indexPath.item]
            configure(cell, with: item)
            return cell
        }

        func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            guard parent.items.indices.contains(indexPath.item) else { return }
            parent.selectedItemID = parent.items[indexPath.item].id
            refreshVisibleItems(in: collectionView)
        }

        func applyItems(to collectionView: UICollectionView) {
            let itemIDs = parent.items.map(\.id)
            if itemIDs != lastItemIDs {
                lastItemIDs = itemIDs
                collectionView.reloadData()
                return
            }
            refreshVisibleItems(in: collectionView)
        }

        private func refreshVisibleItems(in collectionView: UICollectionView) {
            for indexPath in collectionView.indexPathsForVisibleItems {
                guard parent.items.indices.contains(indexPath.item),
                      let cell = collectionView.cellForItem(at: indexPath) else {
                    continue
                }
                configure(cell, with: parent.items[indexPath.item])
            }
        }

        private func configure(_ cell: UICollectionViewCell, with item: ArtworkDownloadItem) {
            cell.backgroundColor = .clear
            cell.contentConfiguration = UIHostingConfiguration {
                parent.row(for: item)
            }
            .margins(.all, 0)
        }

        func restoreSelection(in collectionView: UICollectionView) {
            if let selectedItemID = parent.selectedItemID,
               let row = parent.items.firstIndex(where: { $0.id == selectedItemID }) {
                collectionView.selectItem(
                    at: IndexPath(item: row, section: 0),
                    animated: false,
                    scrollPosition: []
                )
            } else if parent.items.isEmpty == false {
                parent.selectedItemID = parent.items[0].id
                collectionView.selectItem(
                    at: IndexPath(item: 0, section: 0),
                    animated: false,
                    scrollPosition: []
                )
            } else {
                parent.selectedItemID = nil
            }
        }
    }
}

private final class NativeDownloadQueueMasonryUICollectionViewLayout: UICollectionViewLayout {
    var items: [ArtworkDownloadItem] = []
    var layoutKind: DownloadQueueMasonryLayoutKind = .regular

    private var cachedAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var previousCachedAttributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var cachedContentSize: CGSize = .zero

    override var collectionViewContentSize: CGSize {
        cachedContentSize
    }

    override func prepare() {
        super.prepare()
        previousCachedAttributes = cachedAttributes

        guard let collectionView else {
            cachedAttributes = [:]
            cachedContentSize = .zero
            return
        }

        let containerWidth = max(collectionView.bounds.width, 1)
        let metrics = DownloadQueueMasonryPresentation.metrics(
            for: containerWidth,
            layoutKind: layoutKind
        )
        let itemWidth = metrics.itemWidth(for: containerWidth)
        let resolved = DownloadQueueMasonryPlacement.resolve(
            heights: items.map {
                DownloadQueueMasonryPresentation.cardHeight(
                    for: $0,
                    width: itemWidth,
                    layoutKind: layoutKind
                )
            },
            containerWidth: containerWidth,
            metrics: metrics
        )

        var attributes: [IndexPath: UICollectionViewLayoutAttributes] = [:]
        attributes.reserveCapacity(resolved.frames.count)
        for (index, frame) in resolved.frames.enumerated() {
            let indexPath = IndexPath(item: index, section: 0)
            let itemAttributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            itemAttributes.frame = frame
            attributes[indexPath] = itemAttributes
        }

        cachedAttributes = attributes
        cachedContentSize = resolved.size
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        cachedAttributes.values.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        cachedAttributes[indexPath] ?? previousCachedAttributes[indexPath]
    }

    override func initialLayoutAttributesForAppearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        copiedAttributes(for: itemIndexPath)
    }

    override func finalLayoutAttributesForDisappearingItem(
        at itemIndexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        copiedAttributes(for: itemIndexPath)
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView else { return false }
        return NativeGalleryBoundsInvalidation.shouldInvalidate(
            oldSize: collectionView.bounds.size,
            newSize: newBounds.size
        )
    }

    private func copiedAttributes(for indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard let attributes = layoutAttributesForItem(at: indexPath)?.copy()
            as? UICollectionViewLayoutAttributes else {
            return nil
        }
        return attributes
    }
}

private final class NativeDownloadQueueCollectionView: UICollectionView {
    var onSpace: (() -> Void)?
    var onHierarchyAvailable: ((UICollectionView) -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override var keyCommands: [UIKeyCommand]? {
        [
            UIKeyCommand(input: " ", modifierFlags: [], action: #selector(handleSpaceKey))
        ]
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        becomeFirstResponder()
        notifyHierarchyAvailableIfNeeded()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        notifyHierarchyAvailableIfNeeded()
    }

    @objc private func handleSpaceKey() {
        onSpace?()
    }

    private func notifyHierarchyAvailableIfNeeded() {
        guard window != nil else { return }
        onHierarchyAvailable?(self)
    }
}
#endif
