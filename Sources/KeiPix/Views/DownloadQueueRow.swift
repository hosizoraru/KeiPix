import SwiftUI

/// Single row inside `DownloadQueueView`. Lives in its own file so the
/// queue view stays under SwiftLint's 1000-line ceiling and so the row
/// can evolve independently as we add the live-throughput badge,
/// Quick Look button, drag affordance, and focus indicator.
struct DownloadQueueRow: View {
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

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        rowLayout
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(usesPhoneLayout ? 8 : 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .keiInteractiveGlass(18)
            // Subtle accent ring on the focused card so users can see
            // which entry the space bar will preview. Mirrors how
            // Finder paints a halo around the selected file.
            .overlay {
                if isFocused {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.65), lineWidth: 2)
                }
            }
            .modifier(DownloadRowDraggableModifier(fileURL: draggableFileURL))
            .contextMenu {
                contextMenuContent
            }
    }

    @ViewBuilder
    private var rowLayout: some View {
        if usesPhoneLayout {
            phoneLayout
        } else {
            regularLayout
        }
    }

    private var phoneLayout: some View {
        PhoneDownloadQueueRowLayout(
            item: item,
            downloads: downloads,
            canOpen: canOpen,
            open: open,
            retry: retry,
            quickLook: quickLook,
            copied: copied,
            cancel: cancel,
            delete: delete
        )
    }

    private var regularLayout: some View {
        RegularDownloadQueueRowLayout(
            item: item,
            downloads: downloads,
            canOpen: canOpen,
            open: open,
            retry: retry,
            reveal: reveal,
            quickLook: quickLook,
            copied: copied,
            cancel: cancel,
            delete: delete
        )
    }

    private var usesPhoneLayout: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    @ViewBuilder
    private var contextMenuContent: some View {
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
        #if os(macOS)
        Button(L10n.revealInFinder) {
            reveal()
        }
        #endif
        if let pixivURL = item.pixivURL {
            Button(L10n.openInPixiv) {
                PlatformWorkspace.open(pixivURL)
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

private struct RegularDownloadQueueRowLayout: View {
    let item: ArtworkDownloadItem
    let downloads: ArtworkDownloadStore
    let canOpen: Bool
    let open: () -> Void
    let retry: () -> Void
    let reveal: () -> Void
    let quickLook: () -> Void
    let copied: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .top, spacing: 9) {
                DownloadQueueStatusIcon(status: item.status)
                    .font(.title3)
                    .frame(width: 24, height: 24)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.creatorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                DownloadQueueStatusBadge(status: item.status)
            }

            ProgressView(value: item.progress)
                .opacity(item.status == .completed ? 0.55 : 1)

            FlowLayout(spacing: 5) {
                DownloadQueueMetadataChip(
                    item.resolvedArtifactKind.title,
                    systemImage: item.resolvedArtifactKind == .ugoiraZip ? "film.stack" : "photo.stack"
                )
                DownloadQueueMetadataFlow(
                    item: item,
                    downloads: downloads,
                    includesStateBadges: false
                )
            }

            Spacer(minLength: 0)

            DownloadQueueRegularActionRail(
                item: item,
                canOpen: canOpen,
                open: open,
                retry: retry,
                reveal: reveal,
                quickLook: quickLook,
                copied: copied,
                cancel: cancel,
                delete: delete
            )
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct PhoneDownloadQueueRowLayout: View {
    let item: ArtworkDownloadItem
    let downloads: ArtworkDownloadStore
    let canOpen: Bool
    let open: () -> Void
    let retry: () -> Void
    let quickLook: () -> Void
    let copied: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                DownloadQueueStatusIcon(status: item.status)
                    .font(.title3)
                    .frame(width: 22, height: 22)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.creatorName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            ProgressView(value: item.progress)
                .opacity(item.status == .completed ? 0.55 : 1)

            DownloadQueueMetadataFlow(
                item: item,
                downloads: downloads,
                includesStateBadges: true
            )

            DownloadQueuePhoneActionBar(
                item: item,
                canOpen: canOpen,
                open: open,
                retry: retry,
                quickLook: quickLook,
                copied: copied,
                cancel: cancel,
                delete: delete
            )
        }
    }
}

private struct DownloadQueueMetadataFlow: View {
    let item: ArtworkDownloadItem
    let downloads: ArtworkDownloadStore
    let includesStateBadges: Bool

    var body: some View {
        FlowLayout(spacing: 5) {
            if includesStateBadges {
                DownloadQueueStatusBadge(status: item.status)
                DownloadQueueMetadataChip(
                    item.resolvedArtifactKind.title,
                    systemImage: item.resolvedArtifactKind == .ugoiraZip ? "film.stack" : "photo.stack"
                )
            }

            DownloadQueueMetadataChip(item.progressLabel, systemImage: "chart.line.uptrend.xyaxis")

            if let sourcePageLabel = item.sourcePageLabel {
                DownloadQueueMetadataChip(sourcePageLabel, systemImage: "square.stack.3d.up")
            }

            if let queuedAfter = item.queuedAfter, queuedAfter > Date() {
                DownloadQueueMetadataChip(
                    String(
                        format: L10n.retryScheduledFormat,
                        queuedAfter.formatted(date: .omitted, time: .standard)
                    ),
                    systemImage: "timer"
                )
            }

            if let downloadedSize = downloads.downloadedSizeText(for: item) {
                DownloadQueueMetadataChip(downloadedSize, systemImage: "externaldrive")
            }

            if let throughput = downloads.throughputText(for: item) {
                DownloadQueueMetadataChip(
                    throughput,
                    systemImage: "speedometer",
                    tone: .accent,
                    usesMonospacedDigits: true
                )
            }

            if let errorMessage = item.errorMessage {
                DownloadQueueMetadataChip(errorMessage, systemImage: "exclamationmark.triangle.fill", tone: .error)
            } else if let folderPath = item.folderPath {
                #if os(macOS)
                DownloadQueueMetadataChip(folderPath, systemImage: "folder", tone: .path)
                #else
                DownloadQueueMetadataChip(
                    item.resolvedArtifactKind == .imagePages ? L10n.savedToPhotos : L10n.privateAppCache,
                    systemImage: item.resolvedArtifactKind == .imagePages ? "photo.on.rectangle" : "tray.full"
                )
                #endif
            }
        }
    }
}

private struct DownloadQueuePhoneActionBar: View {
    let item: ArtworkDownloadItem
    let canOpen: Bool
    let open: () -> Void
    let retry: () -> Void
    let quickLook: () -> Void
    let copied: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 5) {
            HStack(spacing: 5) {
                if item.status == .failed {
                    DownloadQueueRetryButton(item: item, action: retry)
                } else if item.status == .queued || item.status == .downloading {
                    DownloadQueueCancelButton(action: cancel)
                }

                Spacer(minLength: 4)

                DownloadQueueOpenButton(canOpen: canOpen, action: open)
                DownloadQueueQuickLookButton(canOpen: canOpen, action: quickLook)
                DownloadQueueMoreMenu(
                    item: item,
                    canOpen: canOpen,
                    quickLook: quickLook,
                    reveal: nil,
                    copied: copied,
                    cancel: cancel,
                    delete: delete
                )
            }
        }
        .controlSize(.small)
        .frame(maxWidth: .infinity)
    }
}

private struct DownloadQueueRegularActionRail: View {
    let item: ArtworkDownloadItem
    let canOpen: Bool
    let open: () -> Void
    let retry: () -> Void
    let reveal: () -> Void
    let quickLook: () -> Void
    let copied: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            ViewThatFits(in: .horizontal) {
                expandedActionRail
                compactActionRail
            }
        }
    }

    private var expandedActionRail: some View {
        HStack(spacing: 8) {
            if item.status == .failed {
                DownloadQueueRetryButton(item: item, action: retry)
            }

            if item.status == .queued || item.status == .downloading {
                DownloadQueueCancelButton(action: cancel)
            }

            DownloadQueueOpenButton(canOpen: canOpen, action: open)
            DownloadQueueQuickLookButton(canOpen: canOpen, action: quickLook)
            #if os(macOS)
            DownloadQueueRevealButton(action: reveal)
            #endif
            DownloadQueueMoreMenu(
                item: item,
                canOpen: canOpen,
                quickLook: quickLook,
                reveal: reveal,
                copied: copied,
                cancel: cancel,
                delete: delete
            )
        }
    }

    private var compactActionRail: some View {
        HStack(spacing: 8) {
            if item.status == .failed {
                DownloadQueueRetryButton(item: item, action: retry)
            } else if item.status == .queued || item.status == .downloading {
                DownloadQueueCancelButton(action: cancel)
            }

            DownloadQueueOpenButton(canOpen: canOpen, action: open)
            DownloadQueueMoreMenu(
                item: item,
                canOpen: canOpen,
                quickLook: quickLook,
                reveal: reveal,
                copied: copied,
                cancel: cancel,
                delete: delete
            )
        }
    }
}

private struct DownloadQueueStatusIcon: View {
    let status: ArtworkDownloadStatus

    var body: some View {
        switch status {
        case .queued:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .downloading:
            Image(systemName: "arrow.down.circle.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.tint)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}

private struct DownloadQueueStatusBadge: View {
    let status: ArtworkDownloadStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .keiGlass(10)
    }
}

private struct DownloadQueueMetadataChip: View {
    enum Tone: Equatable {
        case secondary
        case accent
        case error
        case path
    }

    let text: String
    let systemImage: String?
    let tone: Tone
    let usesMonospacedDigits: Bool

    init(
        _ text: String,
        systemImage: String? = nil,
        tone: Tone = .secondary,
        usesMonospacedDigits: Bool = false
    ) {
        self.text = text
        self.systemImage = systemImage
        self.tone = tone
        self.usesMonospacedDigits = usesMonospacedDigits
    }

    var body: some View {
        styledContent
            .font(usesMonospacedDigits ? .caption2.monospacedDigit() : .caption2)
            .lineLimit(tone == .error ? 2 : 1)
            .truncationMode(tone == .path ? .middle : .tail)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background {
                Capsule(style: .continuous)
                    .fill(Color.secondary.opacity(tone == .error ? 0.12 : 0.08))
            }
    }

    @ViewBuilder
    private var styledContent: some View {
        switch tone {
        case .secondary, .path:
            content
                .foregroundStyle(.secondary)
        case .accent:
            content
                .foregroundStyle(.tint)
        case .error:
            content
                .foregroundStyle(.red)
        }
    }

    private var content: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.small)
            }
            Text(text)
        }
    }
}

private struct DownloadQueueRetryButton: View {
    let item: ArtworkDownloadItem
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(L10n.retry, systemImage: "arrow.clockwise")
        }
        .os26GlassIconButton()
        .disabled(item.sourceImageURLs?.isEmpty != false)
        .help(L10n.retry)
    }
}

private struct DownloadQueueCancelButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(L10n.cancelDownload, systemImage: "xmark.circle")
        }
        .os26GlassIconButton()
        .help(L10n.cancelDownload)
    }
}

private struct DownloadQueueOpenButton: View {
    let canOpen: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(L10n.openDownloadedArtwork, systemImage: "book")
        }
        .os26GlassIconButton(prominent: true)
        .disabled(canOpen == false)
        .help(L10n.openDownloadedArtwork)
    }
}

private struct DownloadQueueQuickLookButton: View {
    let canOpen: Bool
    let action: () -> Void

    var body: some View {
        // Quick Look mirrors Finder's space-bar preview. The keyboard
        // shortcut stays on the native list, so rendered buttons never
        // compete for one accelerator.
        Button(action: action) {
            Label(L10n.quickLook, systemImage: "eye")
        }
        .os26GlassIconButton()
        .disabled(canOpen == false)
        .help(L10n.quickLookHint)
    }
}

private struct DownloadQueueRevealButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(L10n.revealInFinder, systemImage: "folder")
        }
        .os26GlassIconButton()
        .help(L10n.revealInFinder)
    }
}

private struct DownloadQueueMoreMenu: View {
    let item: ArtworkDownloadItem
    let canOpen: Bool
    let quickLook: () -> Void
    let reveal: (() -> Void)?
    let copied: () -> Void
    let cancel: () -> Void
    let delete: () -> Void

    var body: some View {
        Menu {
            if let pixivURL = item.pixivURL {
                Button {
                    PlatformWorkspace.open(pixivURL)
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

            #if os(macOS)
            if let reveal {
                Button {
                    reveal()
                } label: {
                    Label(L10n.revealInFinder, systemImage: "folder")
                }
            }
            #endif

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
        .os26GlassIconButton()
        .help(L10n.moreActions)
    }
}

/// Wraps `.draggable(...)` so a row with no readable file renders as a
/// plain row instead of an empty drag source. SwiftUI's `.draggable`
/// always installs a drag recogniser, even when the closure returns an
/// empty payload — we'd rather skip the modifier entirely so the user
/// can't start a phantom drag from a queued or failed row.
struct DownloadRowDraggableModifier: ViewModifier {
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

struct DownloadDragPreview: View {
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
        .glassEffect(.regular, in: Capsule(style: .continuous))
    }
}
