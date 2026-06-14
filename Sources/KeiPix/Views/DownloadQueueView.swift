import QuickLook
import SwiftUI
#if os(iOS)
import UIKit
#endif

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
    /// Selected row for the native queue list. The AppKit/UIKit
    /// container owns keyboard focus and forwards Space to Quick Look,
    /// while SwiftUI keeps the selection value for row chrome.
    @State private var selectedDownloadID: UUID?

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
            .platformPageNavigationChrome(title: L10n.downloads, status: downloadStatusText)
            .quickLookPreview($quickLookURL)
            .overlay(alignment: .bottom) {
                actionMessageOverlay
            }
            .animation(.snappy(duration: 0.18), value: actionMessage)
            .animation(.snappy(duration: 0.18), value: downloadFilterSignature)
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
            if store.downloads.items.isEmpty {
                EmptyStateView(
                    title: L10n.noDownloadsTitle,
                    subtitle: L10n.noDownloadsSubtitle,
                    systemImage: "arrow.down.circle"
                )
            } else {
                downloadOverviewCard
                    .platformGlassControlBar(verticalPadding: 7, topPadding: 2, bottomPadding: 8)
                    .transition(.move(edge: .top).combined(with: .opacity))

                if visibleItems.isEmpty {
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
    }

    private var downloadOverviewCard: some View {
        DownloadQueueOverviewCard(
            downloads: store.downloads,
            showsActionRail: showsDownloadOverviewActionRail,
            requestDangerAction: { pendingDangerAction = $0 },
            copyVisibleLinks: copyVisibleLinks,
            showActionMessage: showActionMessage,
            showCompletedHistory: showCompletedDownloadHistory,
            showFailedHistory: showFailedDownloadHistory
        )
    }

    private var downloadFilterSignature: String {
        [
            store.downloads.downloadQueueFilter.rawValue,
            store.downloads.downloadSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        .joined(separator: "|")
    }

    private var showsDownloadOverviewActionRail: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom != .phone
        #else
        true
        #endif
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
        switch preview {
        case .images(let item, let imageURLs):
            DownloadedArtworkViewer(item: item, imageURLs: imageURLs, store: store)
                .os26SheetChrome(.reader)
        case .ugoira(let item, let zipURL):
            DownloadedUgoiraViewer(item: item, zipURL: zipURL)
                .os26SheetChrome(.standard)
        }
    }

    /// Pulled out of `body` so the type-checker doesn't have to chew
    /// through the row-construction expression alongside every other
    /// modifier on the queue. Each row is wired with focus + space-bar
    /// + the Quick Look handler so the affordance matches Finder's
    /// list view.
    @ViewBuilder
    private func downloadList(items: [ArtworkDownloadItem]) -> some View {
        NativeDownloadQueueListView(
            items: items,
            downloads: store.downloads,
            selectedItemID: $selectedDownloadID,
            canOpen: { store.downloads.hasReadableDownload(for: $0) },
            open: openDownloadedItem,
            retry: retryDownload,
            reveal: revealDownload,
            quickLook: presentQuickLook,
            copied: { showActionMessage(L10n.copied) },
            cancel: { pendingDangerAction = .cancelItem($0) },
            delete: { pendingDangerAction = .deleteItem($0) }
        )
        .nativeBottomTabContentSurface()
    }

    private var downloadStatusText: String {
        if store.downloads.isPaused {
            return "\(L10n.downloadsPaused) · \(store.downloads.filteredItems.count.formatted())"
        }
        // Speedometer line. We only show the aggregate "Total X MB/s"
        // when at least one worker is mid-flight; otherwise the
        // subtitle stays at "count · size" exactly as before so the
        // queue doesn't visibly twitch when downloads finish.
        var components = [
            store.downloads.filteredItems.count.formatted(),
            store.downloads.filteredDownloadedSizeText
        ]
        if let throughputText = store.downloads.aggregateThroughputText {
            components.append(String(format: L10n.downloadThroughputTotalFormat, throughputText))
        }
        return components.joined(separator: " · ")
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
        #if os(macOS)
        if store.downloads.reveal(item) {
            showActionMessage(L10n.revealedDownloadInFinder)
        } else {
            showActionMessage(L10n.openedDownloadFolder)
        }
        #else
        openDownloadedItem(item)
        #endif
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

    private func showCompletedDownloadHistory() {
        withAnimation(.snappy(duration: 0.16)) {
            store.downloads.setDownloadQueueFilter(.completed)
            store.downloads.setDownloadQueueSort(.recentlyUpdated)
        }
    }

    private func showFailedDownloadHistory() {
        withAnimation(.snappy(duration: 0.16)) {
            store.downloads.setDownloadQueueFilter(.failed)
            store.downloads.setDownloadQueueSort(.recentlyUpdated)
        }
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

private struct DownloadQueueOverviewCard: View {
    @Bindable var downloads: ArtworkDownloadStore
    let showsActionRail: Bool
    let requestDangerAction: (DownloadDangerAction) -> Void
    let copyVisibleLinks: () -> Void
    let showActionMessage: (String) -> Void
    let showCompletedHistory: () -> Void
    let showFailedHistory: () -> Void

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        GlassEffectContainer(spacing: 10) {
            if usesCompactPhoneLayout {
                compactLayout
            } else {
                wideLayout
            }
        }
        .controlSize(.small)
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 7) {
            latestCompletedLine
            metricStrip
            filterSearchField
            activeFilterPills
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var wideLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                latestCompletedLine
                    .layoutPriority(1)
                Spacer(minLength: 10)
                if showsActionRail {
                    DownloadQueueActionRail(
                        downloads: downloads,
                        requestDangerAction: requestDangerAction,
                        copyVisibleLinks: copyVisibleLinks,
                        showActionMessage: showActionMessage
                    )
                }
            }

            HStack(alignment: .center, spacing: 10) {
                metricStrip
                    .layoutPriority(1)
                Spacer(minLength: 10)
                filterSearchField
                    .frame(minWidth: 220, idealWidth: 320, maxWidth: 480)
            }

            activeFilterPills
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var latestCompletedLine: some View {
        DownloadQueueLatestSummary(
            snapshot: downloads.historySnapshot,
            usesCompactLayout: usesCompactPhoneLayout
        )
    }

    private var metricStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                DownloadQueueMetricChip(
                    title: L10n.activeDownloads,
                    value: downloads.activeCount.formatted(),
                    systemImage: "arrow.down.circle.fill",
                    tint: .blue,
                    isSelected: downloads.downloadQueueFilter == .active
                ) {
                    withAnimation(.snappy(duration: 0.16)) {
                        downloads.setDownloadQueueFilter(.active)
                        downloads.setDownloadQueueSort(.recentlyUpdated)
                    }
                }
                .disabled(downloads.activeCount == 0)

                DownloadQueueMetricChip(
                    title: L10n.completedDownloads,
                    value: downloads.completedCount.formatted(),
                    systemImage: "checkmark.circle.fill",
                    tint: .green,
                    isSelected: downloads.downloadQueueFilter == .completed,
                    action: showCompletedHistory
                )
                .disabled(downloads.completedCount == 0)

                DownloadQueueMetricChip(
                    title: L10n.failedDownloads,
                    value: downloads.historySnapshot.failedCount.formatted(),
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .red,
                    isSelected: downloads.downloadQueueFilter == .failed,
                    action: showFailedHistory
                )
                .disabled(downloads.historySnapshot.failedCount == 0)

                if usesCompactPhoneLayout == false, downloads.filteredDownloadedByteCount > 0 {
                    DownloadQueueStorageChip(value: downloads.filteredDownloadedSizeText)
                }

                if usesCompactPhoneLayout == false, let throughput = downloads.aggregateThroughputText {
                    DownloadQueueStorageChip(
                        value: String(format: L10n.downloadThroughputTotalFormat, throughput),
                        systemImage: "speedometer"
                    )
                }
            }
            .padding(.vertical, 1)
        }
    }

    private var filterSearchField: some View {
        NativeSearchField(
            text: downloadSearchBinding,
            placeholder: L10n.searchDownloads,
            suggestions: [],
            onSubmit: {},
            onTextChange: { downloads.setDownloadSearchText($0) }
        )
        .frame(minWidth: usesCompactPhoneLayout ? 0 : 220, maxWidth: .infinity)
        .layoutPriority(1)
        .accessibilityLabel(L10n.searchDownloads)
    }

    @ViewBuilder
    private var activeFilterPills: some View {
        if hasActiveFilterPills {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if downloads.downloadQueueFilter != .all {
                        FeedFilterClearChip(
                            title: downloads.downloadQueueFilter.title,
                            clearLabel: L10n.clearFeedFilter,
                            systemImage: "line.3.horizontal.decrease.circle.fill",
                            maximumWidth: 190
                        ) {
                            withAnimation(.snappy(duration: 0.16)) {
                                downloads.setDownloadQueueFilter(.all)
                            }
                        }
                    }

                    if normalizedSearchText.isEmpty == false {
                        FeedFilterClearChip(
                            title: String(format: L10n.activeArtworkFilterFormat, normalizedSearchText),
                            clearLabel: L10n.clearFeedFilter,
                            systemImage: "magnifyingglass.circle.fill",
                            maximumWidth: usesCompactPhoneLayout ? 220 : 260
                        ) {
                            withAnimation(.snappy(duration: 0.16)) {
                                downloads.setDownloadSearchText("")
                            }
                        }
                    }
                }
                .padding(.vertical, 1)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        }
    }

    private var hasActiveFilterPills: Bool {
        downloads.downloadQueueFilter != .all || normalizedSearchText.isEmpty == false
    }

    private var normalizedSearchText: String {
        downloads.downloadSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var downloadSearchBinding: Binding<String> {
        Binding {
            downloads.downloadSearchText
        } set: { value in
            downloads.setDownloadSearchText(value)
        }
    }

    private var usesCompactPhoneLayout: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone && horizontalSizeClass == .compact
        #else
        false
        #endif
    }
}

private struct DownloadQueueLatestSummary: View {
    let snapshot: DownloadQueueHistorySnapshot
    let usesCompactLayout: Bool

    var body: some View {
        if usesCompactLayout {
            summaryContent
                .accessibilityLabel("\(caption): \(title)")
        } else {
            summaryContent
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .keiGlass(14)
                .accessibilityLabel("\(caption): \(title)")
        }
    }

    private var summaryContent: some View {
        Label {
            VStack(alignment: .leading, spacing: usesCompactLayout ? 1 : 2) {
                Text(caption)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(usesCompactLayout ? .subheadline.weight(.semibold) : .callout.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)
                if let completedAt = snapshot.latestCompletedAt {
                    Text(completedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        } icon: {
            Image(systemName: systemImage)
                .font((usesCompactLayout ? Font.body : Font.title3).weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint)
        }
        .labelStyle(.titleAndIcon)
    }

    private var caption: String {
        if snapshot.latestCompletedTitle != nil {
            return L10n.recentlyUpdated
        }
        if snapshot.activeCount > 0 {
            return L10n.downloading
        }
        if snapshot.failedCount > 0 {
            return L10n.failedDownloads
        }
        return L10n.downloads
    }

    private var systemImage: String {
        if snapshot.latestCompletedTitle != nil {
            return "clock.arrow.circlepath"
        }
        if snapshot.activeCount > 0 {
            return "arrow.down.circle.fill"
        }
        if snapshot.failedCount > 0 {
            return "exclamationmark.triangle.fill"
        }
        return "arrow.down.circle"
    }

    private var iconTint: Color {
        if snapshot.activeCount > 0, snapshot.latestCompletedTitle == nil {
            return .blue
        }
        if snapshot.failedCount > 0, snapshot.latestCompletedTitle == nil {
            return .red
        }
        return .secondary
    }

    private var title: String {
        if let latestCompletedTitle = snapshot.latestCompletedTitle {
            return latestCompletedTitle
        }
        if snapshot.activeCount > 0 {
            return L10n.activeDownloads
        }
        if snapshot.failedCount > 0 {
            return L10n.failedDownloads
        }
        return L10n.noDownloadsTitle
    }
}

private struct DownloadQueueMetricChip: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(valueStyle)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .foregroundStyle(titleStyle)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .background(tint.opacity(isSelected ? 0.16 : 0.06), in: Capsule(style: .continuous))
        .keiInteractiveGlass(17)
        .overlay {
            Capsule(style: .continuous)
                .stroke(tint.opacity(isSelected ? 0.45 : 0.18), lineWidth: 1)
        }
        .tint(tint)
        .help("\(value) \(title)")
        .accessibilityLabel("\(value) \(title)")
    }

    private var valueStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.primary)
    }

    private var titleStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.secondary)
    }
}

private struct DownloadQueueStorageChip: View {
    let value: String
    var systemImage = "externaldrive"

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
            Text(value)
                .font(.caption.monospacedDigit().weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .frame(height: 34)
        .keiGlass(17)
        .accessibilityLabel(value)
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

private struct DownloadQueueActionRail: View {
    @Bindable var downloads: ArtworkDownloadStore
    let requestDangerAction: (DownloadDangerAction) -> Void
    let copyVisibleLinks: () -> Void
    let showActionMessage: (String) -> Void

    var body: some View {
        OS26LibraryActionRail {
            regularActions
        }
        .controlSize(.small)
    }

    @ViewBuilder
    private var regularActions: some View {
        destinationControl
        pauseResumeButton
        sortMenu
        filterMenu
        downloadActionsMenu
    }

    private var pauseResumeButton: some View {
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
        .os26GlassIconButton()
        .disabled(downloads.isPaused ? downloads.hasQueuedItems == false : downloads.activeCount == 0)
        .help(downloads.isPaused ? L10n.resumeDownloads : L10n.pauseDownloads)
    }

    private var sortMenu: some View {
        Menu {
            Picker(L10n.sortDownloads, selection: downloadSortBinding) {
                ForEach(DownloadQueueSort.allCases) { sort in
                    Text(sort.title).tag(sort)
                }
            }
        } label: {
            Label(downloads.downloadQueueSort.title, systemImage: "arrow.up.arrow.down")
        }
        .os26GlassIconButton()
        .accessibilityLabel("\(L10n.sortDownloads): \(downloads.downloadQueueSort.title)")
        .help("\(L10n.sortDownloads): \(downloads.downloadQueueSort.title)")
    }

    private var filterMenu: some View {
        Menu {
            Picker(L10n.downloadFilter, selection: downloadFilterBinding) {
                ForEach(DownloadQueueFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
        } label: {
            Label(downloads.downloadQueueFilter.title, systemImage: "line.3.horizontal.decrease.circle")
        }
        .os26GlassIconButton()
        .accessibilityLabel("\(L10n.downloadFilter): \(downloads.downloadQueueFilter.title)")
        .help("\(L10n.downloadFilter): \(downloads.downloadQueueFilter.title) · \(summaryHelpText)")
    }

    private var downloadActionsMenu: some View {
        Menu {
            Button(action: copyVisibleLinks) {
                Label(L10n.copyVisibleDownloadLinks, systemImage: "link")
            }
            .disabled(downloads.filteredPixivLinks.isEmpty)

            #if os(macOS)
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
            #endif

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
        .os26GlassIconButton()
    }

    @ViewBuilder
    private var destinationControl: some View {
        #if os(macOS)
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
            Label(downloads.downloadDestination.title, systemImage: downloads.downloadDestination.systemImage)
        }
        .os26GlassIconButton()
        .help(downloads.downloadDestination.detail)
        #else
        Button {
            showActionMessage(L10n.photosLibraryDestinationHint)
        } label: {
            Label(downloads.downloadDestination.title, systemImage: downloads.downloadDestination.systemImage)
        }
        .os26GlassIconButton()
        .help(downloads.downloadDestination.detail)
        #endif
    }

    private var downloadFilterBinding: Binding<DownloadQueueFilter> {
        Binding {
            downloads.downloadQueueFilter
        } set: { value in
            downloads.setDownloadQueueFilter(value)
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

enum DownloadDangerAction: Identifiable {
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
