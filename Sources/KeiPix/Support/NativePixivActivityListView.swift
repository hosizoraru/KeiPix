import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Native hosted list for Pixiv Web activity.
///
/// The social feed is a linear, text-heavy surface, so AppKit/UIKit owns row
/// reuse and bottom-edge detection while SwiftUI keeps row composition and
/// route actions close to the surrounding app chrome.
@MainActor
struct NativePixivActivityListView {
    let items: [PixivActivityItem]
    var rowHeight: CGFloat = 116
    let onNearContentEnd: @MainActor () -> Void
    let content: @MainActor (PixivActivityItem) -> AnyView
}

#if os(macOS)
extension NativePixivActivityListView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScrollElasticity = .allowed
        scrollView.contentInsets = NSEdgeInsets(top: 14, left: 16, bottom: 18, right: 16)

        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 10)
        tableView.rowHeight = rowHeight
        tableView.backgroundColor = .clear
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator

        let column = NSTableColumn(identifier: Self.columnIdentifier)
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        scrollView.documentView = tableView
        context.coordinator.tableView = tableView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tableView = context.coordinator.tableView else { return }
        tableView.rowHeight = rowHeight
        tableView.tableColumns.first?.width = max(scrollView.contentSize.width, 260)
        context.coordinator.applyItems(to: tableView)
    }

    private static let columnIdentifier = NSUserInterfaceItemIdentifier("pixiv-activity-row")

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: NativePixivActivityListView
        weak var tableView: NSTableView?
        private var lastItemIDs: [String] = []

        init(parent: NativePixivActivityListView) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.items.count
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            parent.rowHeight
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.items.indices.contains(row) else { return nil }
            notifyNearEndIfNeeded(row: row)
            let cell = tableView.makeView(
                withIdentifier: NativePixivActivityTableCell.identifier,
                owner: self
            ) as? NativePixivActivityTableCell ?? NativePixivActivityTableCell()
            cell.identifier = NativePixivActivityTableCell.identifier
            cell.host(parent.content(parent.items[row]))
            return cell
        }

        func applyItems(to tableView: NSTableView) {
            let itemIDs = parent.items.map(\.id)
            if itemIDs != lastItemIDs {
                lastItemIDs = itemIDs
                tableView.reloadData()
                return
            }
            refreshVisibleRows(in: tableView)
        }

        private func refreshVisibleRows(in tableView: NSTableView) {
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            guard visibleRows.location != NSNotFound, visibleRows.length > 0 else { return }
            let end = visibleRows.location + visibleRows.length
            for row in visibleRows.location..<end where parent.items.indices.contains(row) {
                notifyNearEndIfNeeded(row: row)
                guard let cell = tableView.view(
                    atColumn: 0,
                    row: row,
                    makeIfNecessary: false
                ) as? NativePixivActivityTableCell else {
                    continue
                }
                cell.host(parent.content(parent.items[row]))
            }
        }

        private func notifyNearEndIfNeeded(row: Int) {
            guard parent.items.count >= 4, row >= parent.items.count - 4 else { return }
            parent.onNearContentEnd()
        }
    }
}

private final class NativePixivActivityTableCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("native-pixiv-activity-row-cell")

    private var hostingView: NSHostingView<AnyView>?

    func host(_ rootView: AnyView) {
        if let hostingView {
            hostingView.rootView = rootView
            return
        }

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        self.hostingView = hostingView
    }
}
#elseif os(iOS)
extension NativePixivActivityListView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 14, left: 16, bottom: 18, right: 16)

        let collectionView = NativePixivActivityCollectionView(frame: .zero, collectionViewLayout: layout)
        configureCollectionViewForBottomTabContent(collectionView)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Coordinator.cellIdentifier)
        collectionView.onHierarchyAvailable = { [weak coordinator = context.coordinator] collectionView in
            coordinator?.registerContentScrollViewIfNeeded(collectionView)
        }
        context.coordinator.registerContentScrollViewIfNeeded(collectionView)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.registerContentScrollViewIfNeeded(collectionView)
        context.coordinator.applyItems(to: collectionView)
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        static let cellIdentifier = "native-pixiv-activity-row-cell"

        var parent: NativePixivActivityListView
        private var lastItemIDs: [String] = []
        private let contentScrollRegistration = NativeContentScrollRegistration()

        init(parent: NativePixivActivityListView) {
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
            configure(cell, with: parent.items[indexPath.item])
            return cell
        }

        func collectionView(
            _ collectionView: UICollectionView,
            willDisplay cell: UICollectionViewCell,
            forItemAt indexPath: IndexPath
        ) {
            guard indexPath.item >= parent.items.count - 4 else { return }
            parent.onNearContentEnd()
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

        private func configure(_ cell: UICollectionViewCell, with item: PixivActivityItem) {
            cell.backgroundColor = .clear
            cell.contentConfiguration = UIHostingConfiguration {
                parent.content(item)
            }
            .margins(.all, 0)
        }

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            let horizontalInset: CGFloat = 32
            return CGSize(width: max(collectionView.bounds.width - horizontalInset, 260), height: parent.rowHeight)
        }
    }
}

private final class NativePixivActivityCollectionView: UICollectionView {
    var onHierarchyAvailable: ((UICollectionView) -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        notifyHierarchyAvailableIfNeeded()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        notifyHierarchyAvailableIfNeeded()
    }

    private func notifyHierarchyAvailableIfNeeded() {
        guard window != nil else { return }
        onHierarchyAvailable?(self)
    }
}
#endif
