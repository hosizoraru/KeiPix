import AppKit
import QuickLook
import SwiftUI

struct DownloadQueueView: View {
    @Bindable var store: KeiPixStore
    @State private var selectedPreview: DownloadedPreview?
    @State private var pendingDangerAction: DownloadDangerAction?
    @State private var actionMessage: String?
    @State private var didPresentVisualQAPreview = false
    /// Drives `.quickLookPreview(_:)`. Setting this binding to a non-nil
    /// URL pops Apple's system Quick Look panel — same affordance Finder
    /// gives a selected file when the user hits the space bar. We park a
    /// single binding at the view root so toolbar buttons, context-menu
    /// items, and the space-bar key handler all share one source of
    /// truth and only one panel can be on screen at a time.
    @State private var quickLookURL: URL?
    /// ID of the row that should receive space-bar key events. We
    /// install `focusable() + focused()` on each row so the user's
    /// focus walks the queue rather than getting trapped in the
    /// toolbar — matches how Finder's list view handles space-bar
    /// preview against the highlighted row.
    @FocusState private var focusedRowID: UUID?

    var body: some View {
        let visibleItems = store.downloads.filteredItems
        return queueColumnWithChrome(visibleItems: visibleItems)
            .sheet(item: $selectedPreview) { preview in
                previewSheet(preview)
            }
    }

    /// Two-stage body so SwiftUI's type-checker doesn't try to infer
    /// every modifier chain in one expression. The original body
    /// (queue column + ten modifiers + the sheet) tripped the
    /// "compiler is unable to type-check" timeout once the Quick
    /// Look binding, focus, and confirmation dialog all chained
    /// together.
    @ViewBuilder
    private func queueColumnWithChrome(visibleItems: [ArtworkDownloadItem]) -> some View {
        queueColumn(visibleItems: visibleItems)
            .navigationTitle(L10n.downloads)
            .navigationSubtitle(downloadStatusText)
            .quickLookPreview($quickLookURL)
            .overlay(alignment: .bottom) {
                actionMessageOverlay
            }
            .animation(.snappy(duration: 0.18), value: actionMessage)
            .task(id: actionMessage) {
                await dismissActionMessageIfNeeded(actionMessage)
            }
            .task {
                presentDownloadedReaderVisualQAIfNeeded()
            }
            .confirmationDialog(
                pendingDangerAction?.title ?? L10n.downloadActions,
                isPresented: downloadDangerActionBinding,
                titleVisibility: .visible,
                presenting: pendingDangerAction
            ) { action in
                Button(action.confirmButtonTitle, role: .destructive) {
                    perform(action)
                }
                Button(L10n.cancel, role: .cancel) {
                    pendingDangerAction = nil
                }
            } message: { action in
                Text(action.message)
            }
    }

    /// Main vertical layout for the queue. Keeping the header / empty
    /// states / list switch in its own helper means the type-checker
    /// only has to chew through one heavy expression at a time.
    @ViewBuilder
    private func queueColumn(visibleItems: [ArtworkDownloadItem]) -> some View {
        VStack(spacing: 0) {
            DownloadQueueHeader(
                downloads: store.downloads,
                requestDangerAction: { pendingDangerAction = $0 },
                copyVisibleLinks: copyVisibleLinks,
                showActionMessage: showActionMessage
            )
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(.bar)

            if store.downloads.items.isEmpty {
                EmptyStateView(
                    title: L10n.noDownloadsTitle,
                    subtitle: L10n.noDownloadsSubtitle,
                    systemImage: "arrow.down.circle"
                )
            } else if visibleItems.isEmpty {
                EmptyStateView(
                    title: L10n.noMatchingDownloadsTitle,
                    subtitle: L10n.noMatchingDownloadsSubtitle,
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            } else {
                downloadList(items: visibleItems)
            }
        }
    }

    @ViewBuilder
    private var actionMessageOverlay: some View {
        if let actionMessage {
            FloatingStatusBanner(maxWidth: 520) {
                Text(actionMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    /// Pulled out so the `body` expression stays simple enough for the
    /// Swift type-checker. The sheet's enum-switch + `.iPadFriendlySheet`
    /// chained on top of every other modifier on the queue used to push
    /// the body past the type-checker timeout.
    @ViewBuilder
    private func previewSheet(_ preview: DownloadedPreview) -> some View {
        Group {
            switch preview {
            case .images(let item, let imageURLs):
                DownloadedArtworkViewer(item: item, imageURLs: imageURLs, store: store)
            case .ugoira(let item, let zipURL):
                DownloadedUgoiraViewer(item: item, zipURL: zipURL)
            }
        }
        .iPadFriendlySheet()
    }

    private var downloadStatusBadge: some View {
        Text(downloadStatusText)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .help(downloadStatusHelp)
    }

    /// Pulled out of `body` so the type-checker doesn't have to chew
    /// through the row-construction expression alongside every other
    /// modifier on the queue. Each row is wired with focus + space-bar
    /// + the Quick Look handler so the affordance matches Finder's
    /// list view.
    @ViewBuilder
    private func downloadList(items: [ArtworkDownloadItem]) -> some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(items) { item in
                    downloadRow(for: item)
                }
            }
            .padding(18)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
    }

    @ViewBuilder
    private func downloadRow(for item: ArtworkDownloadItem) -> some View {
        DownloadQueueRow(
            item: item,
            downloads: store.downloads,
            canOpen: store.downloads.hasReadableDownload(for: item),
            isFocused: focusedRowID == item.id,
            open: { openDownloadedItem(item) },
            retry: { retryDownload(item) },
            reveal: { revealDownload(item) },
            quickLook: { presentQuickLook(for: item) },
            copied: { showActionMessage(L10n.copied) },
            cancel: { pendingDangerAction = .cancelItem(item) },
            delete: { pendingDangerAction = .deleteItem(item) }
        )
        .focusable()
        .focused($focusedRowID, equals: item.id)
        .onKeyPress(.space) {
            presentQuickLook(for: item)
            return .handled
        }
    }

    private var downloadStatusText: String {
        if store.downloads.isPaused {
            return "\(L10n.downloadsPaused) · \(store.downloads.filteredItems.count.formatted())"
        }
        return "\(store.downloads.filteredItems.count.formatted()) · \(store.downloads.filteredDownloadedSizeText)"
    }

    private var downloadStatusHelp: String {
        String(
            format: L10n.downloadQueueDetailedSummaryFormat,
            store.downloads.filteredItems.count,
            store.downloads.activeCount,
            store.downloads.completedCount,
            store.downloads.filteredDownloadedSizeText
        )
    }

    private func openDownloadedItem(_ item: ArtworkDownloadItem) {
        switch item.resolvedArtifactKind {
        case .imagePages:
            let imageURLs = store.downloads.imageFileURLs(for: item)
            guard imageURLs.isEmpty == false else {
                showActionMessage(L10n.unableToOpenDownloadedArtwork)
                return
            }
            selectedPreview = .images(item: item, imageURLs: imageURLs)
        case .ugoiraZip:
            guard let filePath = item.downloadedFilePaths?.first else {
                showActionMessage(L10n.unableToOpenDownloadedArtwork)
                return
            }
            selectedPreview = .ugoira(item: item, zipURL: URL(fileURLWithPath: filePath))
        }
    }

    private func presentDownloadedReaderVisualQAIfNeeded() {
        guard VisualQALaunchArgument.contains(.downloadedReader),
              didPresentVisualQAPreview == false,
              let item = store.downloads.filteredItems.first(where: { store.downloads.hasReadableImages(for: $0) })
        else {
            return
        }
        didPresentVisualQAPreview = true
        openDownloadedItem(item)
    }

    private var downloadDangerActionBinding: Binding<Bool> {
        Binding {
            pendingDangerAction != nil
        } set: { value in
            if value == false {
                pendingDangerAction = nil
            }
        }
    }

    private func copyVisibleLinks() {
        let links = store.downloads.filteredPixivLinks
        guard links.isEmpty == false else {
            showActionMessage(L10n.noDownloadLinksToCopy)
            return
        }
        PasteboardWriter.copy(links.joined(separator: "\n"))
        showActionMessage(String(format: L10n.copiedLinksFormat, links.count))
    }

    private func retryDownload(_ item: ArtworkDownloadItem) {
        if store.downloads.retry(item) {
            showActionMessage(String(format: L10n.retriedDownloadsFormat, 1))
        } else {
            showActionMessage(L10n.noRetryableDownloads)
        }
    }

    private func revealDownload(_ item: ArtworkDownloadItem) {
        if store.downloads.reveal(item) {
            showActionMessage(L10n.revealedDownloadInFinder)
        } else {
            showActionMessage(L10n.openedDownloadFolder)
        }
    }

    /// Show Apple's Quick Look panel for the row's primary artifact.
    /// We pick the same URL the row uses for `.draggable` (folder for
    /// multi-page artworks, single image for partials, .zip for Ugoira)
    /// so the space-bar preview matches what dragging the row reveals.
    /// `.quickLookPreview` ignores nil URLs without surfacing an alert,
    /// so we only flash the status banner when there's nothing to show.
    private func presentQuickLook(for item: ArtworkDownloadItem) {
        guard let url = quickLookURL(for: item) else {
            showActionMessage(L10n.unableToOpenDownloadedArtwork)
            return
        }
        quickLookURL = url
    }

    /// Resolves the file URL Quick Look should peek at. Mirrors the
    /// drag-to-Finder helper in `DownloadQueueRow.draggableFileURL`,
    /// kept here as a top-level member so the space-bar handler can
    /// resolve URLs without reaching into the row.
    private func quickLookURL(for item: ArtworkDownloadItem) -> URL? {
        guard item.status == .completed else { return nil }
        switch item.resolvedArtifactKind {
        case .imagePages:
            // Quick Look on a folder steps through the contents the
            // same way Finder does, which is exactly what we want for
            // multi-page works. Fall back to the first image when the
            // folder path isn't recorded yet.
            if let folderPath = item.folderPath {
                let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
                if FileManager.default.fileExists(atPath: folderURL.path(percentEncoded: false)) {
                    return folderURL
                }
            }
            return store.downloads.imageFileURLs(for: item).first
        case .ugoiraZip:
            guard let filePath = item.downloadedFilePaths?.first else { return nil }
            let url = URL(fileURLWithPath: filePath, isDirectory: false)
            return FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
        }
    }

    private func showActionMessage(_ message: String) {
        actionMessage = message
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if actionMessage == message {
            actionMessage = nil
        }
    }

    private func perform(_ action: DownloadDangerAction) {
        pendingDangerAction = nil

        switch action {
        case .deleteItem(let item):
            store.downloads.delete(item)
            store.undoAction = AppUndoAction(kind: .restoreDownloads([item]))
            showActionMessage(String(format: L10n.deletedDownloadsFormat, 1))
        case .cancelItem(let item):
            if let restoredItem = store.downloads.cancel(item) {
                store.undoAction = AppUndoAction(kind: .restoreDownloads([restoredItem]))
                showActionMessage(String(format: L10n.cancelledDownloadsFormat, 1))
            } else {
                showActionMessage(L10n.noDownloadRecordsChanged)
            }
        case .cancelVisible:
            let items = store.downloads.cancelFilteredActiveItems()
            if items.isEmpty == false {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showActionMessage(String(format: L10n.cancelledDownloadsFormat, items.count))
            } else {
                showActionMessage(L10n.noDownloadRecordsChanged)
            }
        case .deleteVisible:
            let items = store.downloads.filteredItems.filter { $0.status != .downloading }
            let count = store.downloads.deleteFilteredItems()
            if count > 0 {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showActionMessage(String(format: L10n.deletedDownloadsFormat, count))
            } else {
                showActionMessage(L10n.noDownloadRecordsChanged)
            }
        case .clearFailed:
            let items = store.downloads.filteredItems.filter { $0.status == .failed }
            let count = store.downloads.clearFailedFilteredItems()
            if count > 0 {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showActionMessage(String(format: L10n.deletedDownloadsFormat, count))
            } else {
                showActionMessage(L10n.noDownloadRecordsChanged)
            }
        case .clearInvalid:
            let items = store.downloads.invalidCompletedItems
            let count = store.downloads.clearInvalidItems()
            if count > 0 {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showActionMessage(String(format: L10n.clearedDownloadsFormat, count))
            } else {
                showActionMessage(L10n.noDownloadRecordsChanged)
            }
        case .clearCompleted:
            let items = store.downloads.completedItems
            store.downloads.clearCompleted()
            if items.isEmpty == false {
                store.undoAction = AppUndoAction(kind: .restoreDownloads(items))
                showActionMessage(String(format: L10n.clearedDownloadsFormat, items.count))
            } else {
                showActionMessage(L10n.noDownloadRecordsChanged)
            }
        }
    }
}

private enum DownloadedPreview: Identifiable {
    case images(item: ArtworkDownloadItem, imageURLs: [URL])
    case ugoira(item: ArtworkDownloadItem, zipURL: URL)

    var id: String {
        switch self {
        case .images(let item, _):
            "\(item.id.uuidString)-images"
        case .ugoira(let item, _):
            "\(item.id.uuidString)-ugoira"
        }
    }
}

private struct DownloadQueueHeader: View {
    @Bindable var downloads: ArtworkDownloadStore
    let requestDangerAction: (DownloadDangerAction) -> Void
    let copyVisibleLinks: () -> Void
    let showActionMessage: (String) -> Void

    var body: some View {
        FlowLayout(spacing: 8) {
            Menu {
                Button {
                    openDownloadFolder()
                } label: {
                    Label(L10n.openFolder, systemImage: "folder")
                }

                Button {
                    PasteboardWriter.copy(downloads.downloadDirectoryPath)
                    showActionMessage(L10n.copiedDownloadFolderPath)
                } label: {
                    Label(L10n.copyDownloadFolderPath, systemImage: "doc.on.doc")
                }
            } label: {
                Label(L10n.downloadFolder, systemImage: "folder")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(downloads.downloadDirectoryPath)

            Button {
                if downloads.isPaused {
                    if downloads.resumeQueue() {
                        showActionMessage(L10n.downloadsResumed)
                    } else {
                        showActionMessage(L10n.noDownloadRecordsChanged)
                    }
                } else {
                    if downloads.pauseQueue() {
                        showActionMessage(L10n.downloadsPaused)
                    } else {
                        showActionMessage(L10n.noDownloadRecordsChanged)
                    }
                }
            } label: {
                Label(
                    downloads.isPaused ? L10n.resumeDownloads : L10n.pauseDownloads,
                    systemImage: downloads.isPaused ? "play.circle" : "pause.circle"
                )
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .disabled(downloads.isPaused ? downloads.hasQueuedItems == false : downloads.activeCount == 0)
            .help(downloads.isPaused ? L10n.resumeDownloads : L10n.pauseDownloads)

            HStack(spacing: 6) {
                TextField(L10n.searchDownloads, text: downloadSearchBinding)
                    .textFieldStyle(.roundedBorder)
                    .frame(minWidth: 170, idealWidth: 220, maxWidth: 260)

                Button {
                    downloads.setDownloadSearchText("")
                } label: {
                    Label(L10n.clearSearch, systemImage: "xmark.circle")
                }
                .labelStyle(.iconOnly)
                .disabled(downloads.downloadSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help(L10n.clearSearch)
            }

            Menu {
                Picker(L10n.sortDownloads, selection: downloadSortBinding) {
                    ForEach(DownloadQueueSort.allCases) { sort in
                        Text(sort.title).tag(sort)
                    }
                }
            } label: {
                Label(downloads.downloadQueueSort.title, systemImage: "arrow.up.arrow.down")
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .help("\(L10n.sortDownloads): \(downloads.downloadQueueSort.title)")

            Menu {
                Picker(L10n.downloadFilter, selection: downloadFilterBinding) {
                    ForEach(DownloadQueueFilter.allCases) { filter in
                        Text(filter.title).tag(filter)
                    }
                }
            } label: {
                Label(downloads.downloadQueueFilter.title, systemImage: "line.3.horizontal.decrease.circle")
                    .lineLimit(1)
            }
            .buttonStyle(.bordered)
            .help("\(L10n.downloadFilter): \(downloads.downloadQueueFilter.title) · \(summaryHelpText)")

            Menu {
                Button(action: copyVisibleLinks) {
                    Label(L10n.copyVisibleDownloadLinks, systemImage: "link")
                }
                .disabled(downloads.filteredPixivLinks.isEmpty)

                Button {
                    if downloads.revealFirstFilteredDownload() == false {
                        showActionMessage(
                            downloads.openDownloadDirectory()
                                ? L10n.openedDownloadFolder
                                : L10n.unableToOpenDownloadFolder
                        )
                    } else {
                        showActionMessage(L10n.revealedDownloadInFinder)
                    }
                } label: {
                    Label(L10n.revealFirstVisibleDownload, systemImage: "folder")
                }
                .disabled(downloads.filteredItems.isEmpty)

                Button(role: .destructive) {
                    requestDangerAction(.cancelVisible(count: downloads.filteredCancellableCount))
                } label: {
                    Label(L10n.cancelVisibleDownloads, systemImage: "xmark.circle")
                }
                .disabled(downloads.filteredCancellableCount == 0)

                Button(role: .destructive) {
                    requestDangerAction(.deleteVisible(count: downloads.filteredDeletableCount))
                } label: {
                    Label(L10n.deleteVisibleDownloads, systemImage: "trash")
                }
                .disabled(downloads.filteredDeletableCount == 0)

                Divider()

                Button {
                    let count = downloads.retryFailedFilteredItems()
                    showActionMessage(
                        count > 0
                            ? String(format: L10n.retriedDownloadsWithBackoffFormat, count)
                            : L10n.noRetryableDownloads
                    )
                } label: {
                    Label(L10n.retryFailedDownloads, systemImage: "arrow.clockwise")
                }
                .disabled(downloads.failedFilteredCount == 0)

                Button(role: .destructive) {
                    requestDangerAction(.clearFailed(count: downloads.failedFilteredCount))
                } label: {
                    Label(L10n.clearFailedDownloads, systemImage: "trash")
                }
                .disabled(downloads.failedFilteredCount == 0)

                Divider()

                Button(role: .destructive) {
                    requestDangerAction(.clearInvalid(count: downloads.invalidCompletedItems.count))
                } label: {
                    Label(L10n.clearInvalidDownloads, systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                }
                .disabled(downloads.invalidCompletedItems.isEmpty)

                Button(role: .destructive) {
                    requestDangerAction(.clearCompleted(count: downloads.completedCount))
                } label: {
                    Label(L10n.clearCompleted, systemImage: "checkmark.circle")
                }
                .disabled(downloads.completedCount == 0)
            } label: {
                Label(L10n.downloadActions, systemImage: "ellipsis.circle")
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.small)
    }

    private var downloadFilterBinding: Binding<DownloadQueueFilter> {
        Binding {
            downloads.downloadQueueFilter
        } set: { value in
            downloads.setDownloadQueueFilter(value)
        }
    }

    private var downloadSearchBinding: Binding<String> {
        Binding {
            downloads.downloadSearchText
        } set: { value in
            downloads.setDownloadSearchText(value)
        }
    }

    private var downloadSortBinding: Binding<DownloadQueueSort> {
        Binding {
            downloads.downloadQueueSort
        } set: { value in
            downloads.setDownloadQueueSort(value)
        }
    }

    private var summaryHelpText: String {
        String(
            format: L10n.downloadQueueDetailedSummaryFormat,
            downloads.filteredItems.count,
            downloads.activeCount,
            downloads.completedCount,
            downloads.filteredDownloadedSizeText
        )
    }

    private func openDownloadFolder() {
        showActionMessage(
            downloads.openDownloadDirectory()
                ? L10n.openedDownloadFolder
                : L10n.unableToOpenDownloadFolder
        )
    }
}

private struct DownloadQueueRow: View {
    let item: ArtworkDownloadItem
    @Bindable var downloads: ArtworkDownloadStore
    let canOpen: Bool
    let isFocused: Bool
    let open: () -> Void
    let retry: () -> Void
    let reveal: () -> Void
    let quickLook: () -> Void
    let copied: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            statusIcon
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(item.status.title)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .keiGlass(10)

                    Text(item.resolvedArtifactKind.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Text(item.creatorName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                ProgressView(value: item.progress)
                    .opacity(item.status == .completed ? 0.55 : 1)

                HStack(spacing: 8) {
                    Text(item.progressLabel)
                    if let sourcePageLabel = item.sourcePageLabel {
                        Text(sourcePageLabel)
                    }
                    if let queuedAfter = item.queuedAfter, queuedAfter > Date() {
                        Text(String(
                            format: L10n.retryScheduledFormat,
                            queuedAfter.formatted(date: .omitted, time: .standard)
                        ))
                    }
                    if let downloadedSize = downloads.downloadedSizeText(for: item) {
                        Text(downloadedSize)
                    }
                    if let errorMessage = item.errorMessage {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    } else if let folderPath = item.folderPath {
                        Text(folderPath)
                            .truncationMode(.middle)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 10)

            if item.status == .failed {
                Button {
                    retry()
                } label: {
                    Label(L10n.retry, systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .disabled(item.sourceImageURLs?.isEmpty != false)
                .help(L10n.retry)
            }

            if item.status == .queued || item.status == .downloading {
                Button {
                    cancel()
                } label: {
                    Label(L10n.cancelDownload, systemImage: "xmark.circle")
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.bordered)
                .help(L10n.cancelDownload)
            }

            Button {
                open()
            } label: {
                Label(L10n.openDownloadedArtwork, systemImage: "book")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderedProminent)
            .disabled(canOpen == false)
            .help(L10n.openDownloadedArtwork)

            // Quick Look — same affordance Finder hands to a selected
            // file via the space bar. Disabled for queued / failed
            // rows where there's no on-disk artifact yet. The space
            // shortcut is wired at the row level (focused() + .onKeyPress)
            // rather than on the button so multiple rendered buttons
            // don't fight over a single accelerator.
            Button {
                quickLook()
            } label: {
                Label(L10n.quickLook, systemImage: "eye")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .disabled(canOpen == false)
            .help(L10n.quickLookHint)

            Button {
                reveal()
            } label: {
                Label(L10n.revealInFinder, systemImage: "folder")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.revealInFinder)

            Menu {
                if let pixivURL = item.pixivURL {
                    Button {
                        NSWorkspace.shared.open(pixivURL)
                    } label: {
                        Label(L10n.openInPixiv, systemImage: "safari")
                    }

                    Button {
                        PasteboardWriter.copy(pixivURL.absoluteString)
                        copied()
                    } label: {
                        Label(L10n.copyLink, systemImage: "link")
                    }
                }

                Button {
                    quickLook()
                } label: {
                    Label(L10n.quickLook, systemImage: "eye")
                }
                .disabled(canOpen == false)

                Button {
                    reveal()
                } label: {
                    Label(L10n.revealInFinder, systemImage: "folder")
                }

                Divider()

                if item.status == .queued || item.status == .downloading {
                    Button(role: .destructive, action: cancel) {
                        Label(L10n.cancelDownload, systemImage: "xmark.circle")
                    }
                }

                Button(role: .destructive, action: delete) {
                    Label(L10n.deleteDownload, systemImage: "trash")
                }
                .disabled(item.status == .downloading)
            } label: {
                Label(L10n.moreActions, systemImage: "ellipsis.circle")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.bordered)
            .help(L10n.moreActions)
        }
        .padding(12)
        .keiPanel(16)
        // Subtle accent ring on the focused row so users can see which
        // entry the space bar will preview. Mirrors how Finder's list
        // view paints a halo around the selected file.
        .overlay {
            if isFocused {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.65), lineWidth: 2)
            }
        }
        .modifier(DownloadRowDraggableModifier(fileURL: draggableFileURL))
        .contextMenu {
            if item.status == .failed {
                Button(L10n.retry) {
                    retry()
                }
                .disabled(item.sourceImageURLs?.isEmpty != false)
            }
            Button(L10n.quickLook) {
                quickLook()
            }
            .disabled(canOpen == false)
            Button(L10n.revealInFinder) {
                reveal()
            }
            if let pixivURL = item.pixivURL {
                Button(L10n.openInPixiv) {
                    NSWorkspace.shared.open(pixivURL)
                }
                Button(L10n.copyLink) {
                    PasteboardWriter.copy(pixivURL.absoluteString)
                    copied()
                }
            }
            if item.status == .queued || item.status == .downloading {
                Button(role: .destructive, action: cancel) {
                    Text(L10n.cancelDownload)
                }
            }
            Button(role: .destructive, action: delete) {
                Text(L10n.deleteDownload)
            }
            .disabled(item.status == .downloading)
        }
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch item.status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .downloading:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    /// File URL that should be promised to Finder when the user starts
    /// dragging the row. For image-page artworks we pick the folder so
    /// the whole multi-page set drags as one bundle (Finder will surface
    /// it as a folder copy, which is the same shape the Reveal-in-Finder
    /// command opens). For Ugoira we pick the .zip file. Returns `nil`
    /// for queued / failed / cancelled rows so SwiftUI hides the drag
    /// affordance entirely.
    private var draggableFileURL: URL? {
        guard item.status == .completed else { return nil }
        switch item.resolvedArtifactKind {
        case .imagePages:
            // Prefer the folder so multi-page artworks drag as one
            // selection. Fall back to the first written file when the
            // folder path got pruned (older queue entries from before
            // we persisted `folderPath`).
            if let folderPath = item.folderPath {
                let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
                if downloads.fileManager.fileExists(atPath: folderURL.path(percentEncoded: false)) {
                    return folderURL
                }
            }
            return downloads.imageFileURLs(for: item).first
        case .ugoiraZip:
            guard let filePath = item.downloadedFilePaths?.first else { return nil }
            let url = URL(fileURLWithPath: filePath, isDirectory: false)
            return downloads.fileManager.fileExists(atPath: url.path(percentEncoded: false)) ? url : nil
        }
    }
}

/// Wraps `.draggable(...)` so a row with no readable file renders as a
/// plain row instead of an empty drag source. SwiftUI's `.draggable`
/// always installs a drag recogniser, even when the closure returns an
/// empty payload — we'd rather skip the modifier entirely so the user
/// can't start a phantom drag from a queued or failed row.
private struct DownloadRowDraggableModifier: ViewModifier {
    let fileURL: URL?

    func body(content: Content) -> some View {
        if let fileURL {
            content
                .draggable(fileURL) {
                    DownloadDragPreview(fileURL: fileURL)
                }
        } else {
            content
        }
    }
}

private struct DownloadDragPreview: View {
    let fileURL: URL

    var body: some View {
        let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
        Label(
            fileURL.lastPathComponent,
            systemImage: isDirectory ? "folder" : "doc"
        )
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
    }
}

private enum DownloadDangerAction: Identifiable {
    case deleteItem(ArtworkDownloadItem)
    case cancelItem(ArtworkDownloadItem)
    case cancelVisible(count: Int)
    case deleteVisible(count: Int)
    case clearFailed(count: Int)
    case clearInvalid(count: Int)
    case clearCompleted(count: Int)

    var id: String {
        switch self {
        case .deleteItem(let item):
            "delete-\(item.id.uuidString)"
        case .cancelItem(let item):
            "cancel-\(item.id.uuidString)"
        case .cancelVisible(let count):
            "cancel-visible-\(count)"
        case .deleteVisible(let count):
            "delete-visible-\(count)"
        case .clearFailed(let count):
            "clear-failed-\(count)"
        case .clearInvalid(let count):
            "clear-invalid-\(count)"
        case .clearCompleted(let count):
            "clear-completed-\(count)"
        }
    }

    var title: String {
        switch self {
        case .deleteItem:
            L10n.deleteDownload
        case .cancelItem:
            L10n.cancelDownload
        case .cancelVisible:
            L10n.cancelVisibleDownloads
        case .deleteVisible:
            L10n.deleteVisibleDownloads
        case .clearFailed:
            L10n.clearFailedDownloads
        case .clearInvalid:
            L10n.clearInvalidDownloads
        case .clearCompleted:
            L10n.clearCompleted
        }
    }

    var confirmButtonTitle: String { title }

    var message: String {
        switch self {
        case .deleteItem(let item):
            String(format: L10n.deleteDownloadConfirmationFormat, item.title)
        case .cancelItem(let item):
            String(format: L10n.cancelDownloadConfirmationFormat, item.title)
        case .cancelVisible(let count):
            String(format: L10n.cancelVisibleDownloadsConfirmationFormat, count)
        case .deleteVisible(let count):
            String(format: L10n.deleteVisibleDownloadsConfirmationFormat, count)
        case .clearFailed(let count):
            String(format: L10n.clearFailedDownloadsConfirmationFormat, count)
        case .clearInvalid(let count):
            String(format: L10n.clearInvalidDownloadsConfirmationFormat, count)
        case .clearCompleted(let count):
            String(format: L10n.clearCompletedDownloadsConfirmationFormat, count)
        }
    }
}
