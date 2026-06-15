import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Native list container for the download queue.
///
/// The first P1 slice moves row virtualization, selection, and hardware-key
/// handling to AppKit/UIKit while preserving the existing SwiftUI row as the
/// hosted content. Follow-up work can replace the hosted row with fully native
/// cells once the interaction contract is stable.
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
        scrollView.contentInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

        let tableView = NativeDownloadQueueTableView()
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 10)
        tableView.rowHeight = 116
        tableView.backgroundColor = .clear
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.onSpace = { [weak coordinator = context.coordinator] in
            coordinator?.parent.quickLookSelectedItem()
        }

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
        tableView.tableColumns.first?.width = max(scrollView.contentSize.width, 240)
        context.coordinator.applyItems(to: tableView)
        context.coordinator.restoreSelection()
    }

    private static let columnIdentifier = NSUserInterfaceItemIdentifier("download-row")

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: NativeDownloadQueueListView
        weak var tableView: NSTableView?
        private var lastItemIDs: [UUID] = []

        init(parent: NativeDownloadQueueListView) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.items.count
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            116
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.items.indices.contains(row) else { return nil }
            let item = parent.items[row]
            let cell = tableView.makeView(
                withIdentifier: NativeDownloadTableCell.identifier,
                owner: self
            ) as? NativeDownloadTableCell ?? NativeDownloadTableCell()
            cell.identifier = NativeDownloadTableCell.identifier
            cell.host(AnyView(parent.row(for: item)))
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
                guard let cell = tableView.view(
                    atColumn: 0,
                    row: row,
                    makeIfNecessary: false
                ) as? NativeDownloadTableCell else {
                    continue
                }
                cell.host(AnyView(parent.row(for: parent.items[row])))
            }
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView else { return }
            let row = tableView.selectedRow
            guard parent.items.indices.contains(row) else { return }
            parent.selectedItemID = parent.items[row].id
        }

        func restoreSelection() {
            guard let tableView else { return }
            if let selectedItemID = parent.selectedItemID,
               let row = parent.items.firstIndex(where: { $0.id == selectedItemID }) {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            } else if parent.items.isEmpty == false {
                parent.selectedItemID = parent.items[0].id
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            } else {
                parent.selectedItemID = nil
                tableView.deselectAll(nil)
            }
        }
    }
}

private final class NativeDownloadQueueTableView: NSTableView {
    var onSpace: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            onSpace?()
            return
        }
        super.keyDown(with: event)
    }
}

private final class NativeDownloadTableCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("native-download-row-cell")

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
extension NativeDownloadQueueListView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 4
        layout.sectionInset = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

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
        context.coordinator.updateLayoutInsets(for: collectionView)
        context.coordinator.registerContentScrollViewIfNeeded(collectionView)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.registerContentScrollViewIfNeeded(collectionView)
        context.coordinator.updateLayoutInsets(for: collectionView)
        context.coordinator.applyItems(to: collectionView)
        context.coordinator.restoreSelection(in: collectionView)
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        static let cellIdentifier = "native-download-row-cell"

        var parent: NativeDownloadQueueListView
        private var lastItemIDs: [UUID] = []
        private let compactPhoneRowHeight: CGFloat = 132
        private let compactPhoneSupplementalMetadataHeight: CGFloat = 18
        private let regularRowHeight: CGFloat = 124
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

        func updateLayoutInsets(for collectionView: UICollectionView) {
            guard let layout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout else {
                return
            }
            let isCompactPhone = collectionView.traitCollection.horizontalSizeClass == .compact
            let horizontalInset: CGFloat = isCompactPhone ? 10 : 18
            let desiredLineSpacing: CGFloat = isCompactPhone ? 4 : 6
            let desiredInsets = UIEdgeInsets(
                top: isCompactPhone ? 6 : 18,
                left: horizontalInset,
                bottom: isCompactPhone ? 8 : 18,
                right: horizontalInset
            )
            guard layout.sectionInset != desiredInsets || layout.minimumLineSpacing != desiredLineSpacing else {
                return
            }
            layout.sectionInset = desiredInsets
            layout.minimumLineSpacing = desiredLineSpacing
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

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            let isCompactPhone = collectionView.traitCollection.horizontalSizeClass == .compact
            let horizontalInset: CGFloat = isCompactPhone ? 20 : 36
            let baseHeight = isCompactPhone ? compactPhoneRowHeight : regularRowHeight
            let supplementalHeight: CGFloat
            if isCompactPhone,
               parent.items.indices.contains(indexPath.item) {
                let item = parent.items[indexPath.item]
                supplementalHeight = item.needsCompactSupplementalMetadataHeight
                    ? compactPhoneSupplementalMetadataHeight
                    : 0
            } else {
                supplementalHeight = 0
            }
            return CGSize(
                width: max(collectionView.bounds.width - horizontalInset, isCompactPhone ? 280 : 240),
                height: baseHeight + supplementalHeight
            )
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

private extension ArtworkDownloadItem {
    var needsCompactSupplementalMetadataHeight: Bool {
        errorMessage?.isEmpty == false || folderPath != nil
    }
}
#endif
