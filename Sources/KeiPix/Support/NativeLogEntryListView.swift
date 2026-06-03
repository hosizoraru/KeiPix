import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Native list container for the in-app log viewer.
///
/// SwiftUI still formats each row and owns filtering/copy actions, while
/// NSTableView / UICollectionView handles dense row reuse and scrolling.
@MainActor
struct NativeLogEntryListView {
    let entries: [LogEntry]
    var rowHeight: CGFloat = 74
    let content: (LogEntry) -> AnyView
}

#if os(macOS)
extension NativeLogEntryListView: NSViewRepresentable {
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
        scrollView.contentInsets = NSEdgeInsets(top: 8, left: 10, bottom: 10, right: 10)

        let tableView = NSTableView()
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 6)
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
        tableView.tableColumns.first?.width = max(scrollView.contentSize.width, 240)
        context.coordinator.applyEntries(to: tableView)
    }

    private static let columnIdentifier = NSUserInterfaceItemIdentifier("log-row")

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: NativeLogEntryListView
        weak var tableView: NSTableView?
        private var lastEntryIDs: [UUID] = []

        init(parent: NativeLogEntryListView) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.entries.count
        }

        func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
            parent.rowHeight
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.entries.indices.contains(row) else { return nil }
            let cell = tableView.makeView(
                withIdentifier: NativeLogEntryTableCell.identifier,
                owner: self
            ) as? NativeLogEntryTableCell ?? NativeLogEntryTableCell()
            cell.identifier = NativeLogEntryTableCell.identifier
            cell.host(parent.content(parent.entries[row]))
            return cell
        }

        func applyEntries(to tableView: NSTableView) {
            let entryIDs = parent.entries.map(\.id)
            if entryIDs != lastEntryIDs {
                lastEntryIDs = entryIDs
                tableView.reloadData()
                return
            }
            refreshVisibleRows(in: tableView)
        }

        private func refreshVisibleRows(in tableView: NSTableView) {
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            guard visibleRows.location != NSNotFound, visibleRows.length > 0 else { return }
            let end = visibleRows.location + visibleRows.length
            for row in visibleRows.location..<end where parent.entries.indices.contains(row) {
                guard let cell = tableView.view(
                    atColumn: 0,
                    row: row,
                    makeIfNecessary: false
                ) as? NativeLogEntryTableCell else {
                    continue
                }
                cell.host(parent.content(parent.entries[row]))
            }
        }
    }
}

private final class NativeLogEntryTableCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("native-log-entry-row-cell")

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
extension NativeLogEntryListView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.minimumLineSpacing = 6
        layout.sectionInset = UIEdgeInsets(top: 8, left: 10, bottom: 10, right: 10)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.dataSource = context.coordinator
        collectionView.delegate = context.coordinator
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Coordinator.cellIdentifier)
        return collectionView
    }

    func updateUIView(_ collectionView: UICollectionView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applyEntries(to: collectionView)
    }

    @MainActor
    final class Coordinator: NSObject, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
        static let cellIdentifier = "native-log-entry-row-cell"

        var parent: NativeLogEntryListView
        private var lastEntryIDs: [UUID] = []

        init(parent: NativeLogEntryListView) {
            self.parent = parent
        }

        func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
            parent.entries.count
        }

        func collectionView(
            _ collectionView: UICollectionView,
            cellForItemAt indexPath: IndexPath
        ) -> UICollectionViewCell {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.cellIdentifier,
                for: indexPath
            )
            guard parent.entries.indices.contains(indexPath.item) else { return cell }
            configure(cell, with: parent.entries[indexPath.item])
            return cell
        }

        func applyEntries(to collectionView: UICollectionView) {
            let entryIDs = parent.entries.map(\.id)
            if entryIDs != lastEntryIDs {
                lastEntryIDs = entryIDs
                collectionView.reloadData()
                return
            }
            refreshVisibleItems(in: collectionView)
        }

        private func refreshVisibleItems(in collectionView: UICollectionView) {
            for indexPath in collectionView.indexPathsForVisibleItems {
                guard parent.entries.indices.contains(indexPath.item),
                      let cell = collectionView.cellForItem(at: indexPath) else {
                    continue
                }
                configure(cell, with: parent.entries[indexPath.item])
            }
        }

        private func configure(_ cell: UICollectionViewCell, with entry: LogEntry) {
            cell.backgroundColor = .clear
            cell.contentConfiguration = UIHostingConfiguration {
                parent.content(entry)
            }
            .margins(.all, 0)
        }

        func collectionView(
            _ collectionView: UICollectionView,
            layout collectionViewLayout: UICollectionViewLayout,
            sizeForItemAt indexPath: IndexPath
        ) -> CGSize {
            let horizontalInset: CGFloat = 20
            return CGSize(width: max(collectionView.bounds.width - horizontalInset, 240), height: parent.rowHeight)
        }
    }
}
#endif
