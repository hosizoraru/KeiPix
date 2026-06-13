import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Native hosted list container for artwork and novel comment threads.
///
/// The detail pages keep ownership of comment loading, reply state, and row
/// actions. This bridge moves the top-level row container into AppKit/UIKit so
/// the surface can evolve toward native list reuse without rewriting the
/// comment row behavior in the same step.
@MainActor
struct NativeCommentThreadListView {
    let comments: [PixivComment]
    let content: @MainActor (PixivComment) -> AnyView
}

#if os(macOS)
extension NativeCommentThreadListView: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NativeCommentThreadIntrinsicHeightTableView {
        let tableView = NativeCommentThreadIntrinsicHeightTableView()
        tableView.headerView = nil
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.usesAutomaticRowHeights = true
        tableView.selectionHighlightStyle = .none
        tableView.intercellSpacing = NSSize(width: 0, height: 12)
        tableView.rowHeight = 136
        tableView.backgroundColor = .clear
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator

        let column = NSTableColumn(identifier: Self.columnIdentifier)
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)

        context.coordinator.tableView = tableView
        return tableView
    }

    func updateNSView(_ tableView: NativeCommentThreadIntrinsicHeightTableView, context: Context) {
        context.coordinator.parent = self
        tableView.tableColumns.first?.width = max(tableView.bounds.width, 240)
        context.coordinator.applyComments(to: tableView)
    }

    private static let columnIdentifier = NSUserInterfaceItemIdentifier("comment-thread-row")

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var parent: NativeCommentThreadListView
        weak var tableView: NativeCommentThreadIntrinsicHeightTableView?
        private var lastCommentIDs: [Int] = []

        init(parent: NativeCommentThreadListView) {
            self.parent = parent
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            parent.comments.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard parent.comments.indices.contains(row) else { return nil }
            let cell = tableView.makeView(
                withIdentifier: NativeCommentThreadTableCell.identifier,
                owner: self
            ) as? NativeCommentThreadTableCell ?? NativeCommentThreadTableCell()
            cell.identifier = NativeCommentThreadTableCell.identifier
            cell.host(parent.content(parent.comments[row]))
            return cell
        }

        func applyComments(to tableView: NativeCommentThreadIntrinsicHeightTableView) {
            let commentIDs = parent.comments.map(\.id)
            if commentIDs != lastCommentIDs {
                lastCommentIDs = commentIDs
                tableView.reloadData()
            } else {
                refreshVisibleRows(in: tableView)
            }

            if parent.comments.isEmpty == false {
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: 0..<parent.comments.count))
            }
            tableView.invalidateIntrinsicContentSize()
        }

        private func refreshVisibleRows(in tableView: NSTableView) {
            let visibleRows = tableView.rows(in: tableView.visibleRect)
            guard visibleRows.location != NSNotFound, visibleRows.length > 0 else { return }
            let end = visibleRows.location + visibleRows.length
            for row in visibleRows.location..<end where parent.comments.indices.contains(row) {
                guard let cell = tableView.view(
                    atColumn: 0,
                    row: row,
                    makeIfNecessary: false
                ) as? NativeCommentThreadTableCell else {
                    continue
                }
                cell.host(parent.content(parent.comments[row]))
            }
        }
    }
}

final class NativeCommentThreadIntrinsicHeightTableView: NSTableView {
    override var intrinsicContentSize: NSSize {
        layoutSubtreeIfNeeded()
        guard numberOfRows > 0 else {
            return NSSize(width: NSView.noIntrinsicMetric, height: 0)
        }
        let lastRowBottom = rect(ofRow: numberOfRows - 1).maxY
        let fallbackHeight = CGFloat(numberOfRows) * (rowHeight + intercellSpacing.height)
        return NSSize(width: NSView.noIntrinsicMetric, height: max(lastRowBottom, fallbackHeight))
    }

    override func reloadData() {
        super.reloadData()
        invalidateIntrinsicContentSize()
    }
}

private final class NativeCommentThreadTableCell: NSTableCellView {
    static let identifier = NSUserInterfaceItemIdentifier("native-comment-thread-row-cell")

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
extension NativeCommentThreadListView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> NativeCommentThreadIntrinsicHeightTableView {
        let tableView = NativeCommentThreadIntrinsicHeightTableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 148
        tableView.isScrollEnabled = false
        tableView.showsVerticalScrollIndicator = false
        tableView.allowsSelection = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Coordinator.cellIdentifier)

        context.coordinator.configureDataSource(for: tableView)
        context.coordinator.applySnapshot(to: tableView)
        return tableView
    }

    func updateUIView(_ tableView: NativeCommentThreadIntrinsicHeightTableView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.applySnapshot(to: tableView)
    }

    @MainActor
    final class Coordinator: NSObject {
        static let cellIdentifier = "native-comment-thread-row-cell"

        var parent: NativeCommentThreadListView
        private var dataSource: UITableViewDiffableDataSource<Int, PixivComment>?

        init(parent: NativeCommentThreadListView) {
            self.parent = parent
        }

        func configureDataSource(for tableView: NativeCommentThreadIntrinsicHeightTableView) {
            dataSource = UITableViewDiffableDataSource<Int, PixivComment>(
                tableView: tableView
            ) { [weak self] tableView, _, comment in
                guard let self else { return UITableViewCell() }
                let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellIdentifier) ?? UITableViewCell()
                cell.backgroundColor = .clear
                cell.selectionStyle = .none
                cell.contentConfiguration = UIHostingConfiguration {
                    parent.content(comment)
                }
                .margins(.all, 0)
                return cell
            }
        }

        func applySnapshot(to tableView: NativeCommentThreadIntrinsicHeightTableView) {
            var snapshot = NSDiffableDataSourceSnapshot<Int, PixivComment>()
            snapshot.appendSections([0])
            snapshot.appendItems(parent.comments, toSection: 0)
            dataSource?.apply(snapshot, animatingDifferences: false) {
                tableView.invalidateIntrinsicContentSize()
            }
        }
    }
}

final class NativeCommentThreadIntrinsicHeightTableView: UITableView {
    override var contentSize: CGSize {
        didSet {
            guard oldValue.height != contentSize.height else { return }
            invalidateIntrinsicContentSize()
        }
    }

    override var intrinsicContentSize: CGSize {
        layoutIfNeeded()
        return CGSize(width: UIView.noIntrinsicMetric, height: contentSize.height)
    }
}
#endif
