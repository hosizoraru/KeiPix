import SwiftUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct PixivIDOpenSheet: View {
    @Bindable var store: KeiPixStore
    let showStatus: (String) -> Void
    var prepareForOpen: () -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @State private var target: PixivIDOpenTarget = .artwork
    @State private var rawID = ""

    var body: some View {
        GeometryReader { proxy in
            let layout = PixivIDOpenSheetLayout(size: proxy.size, platform: ReaderPlatformKind.current)

            sheetContent(layout: layout)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        #if os(macOS)
        .frame(width: 460)
        #endif
        #if os(iOS)
        .presentationDetents(PixivIDOpenSheetLayout.mobilePresentationDetents)
        .presentationDragIndicator(.visible)
        #endif
    }

    private func sheetContent(layout: PixivIDOpenSheetLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(layout: layout)

            Divider()

            VStack(alignment: .leading, spacing: layout.contentSpacing) {
                if layout.isCompact {
                    compactPasteButton
                }

                Picker(L10n.openPixivIDTarget, selection: $target) {
                    ForEach(PixivIDOpenTarget.allCases) { option in
                        Label(option.title, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)

                NativeSearchField(
                    text: $rawID,
                    placeholder: target.placeholder,
                    suggestions: [],
                    onSubmit: openID,
                    onTextChange: { rawID = $0 }
                )
                .accessibilityLabel(target.title)

                nativeDropTarget

                Text(L10n.pixivIDQuickOpenHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(layout.contentInsets)

            Spacer(minLength: 0)

            Divider()

            HStack {
                Button(L10n.cancel) {
                    dismiss()
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    openID()
                } label: {
                    Label(L10n.open, systemImage: target.systemImage)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .keyboardShortcut(.defaultAction)
                .disabled(normalizedID == nil)
            }
            .padding(layout.footerInsets)
        }
    }

    private func header(layout: PixivIDOpenSheetLayout) -> some View {
        SheetHeaderRail(
            overline: layout.isCompact ? nil : L10n.quickPixivID,
            title: L10n.openPixivID,
            subtitle: L10n.openPixivIDHint,
            leading: {
                SheetHeaderIcon(systemImage: "number", tint: .accentColor)
            },
            trailing: {
                if layout.isCompact == false {
                    SheetHeaderActionButton(
                        title: L10n.pasteFromClipboard,
                        systemImage: "doc.on.clipboard",
                        action: pasteFromClipboard,
                        isDisabled: PasteboardWriter.currentString() == nil
                    )
                }
            }
        )
    }

    private var compactPasteButton: some View {
        Button(action: pasteFromClipboard) {
            HStack(spacing: 10) {
                Image(systemName: "doc.on.clipboard")
                    .font(.callout.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)

                Text(L10n.pasteFromClipboard)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Spacer(minLength: 8)

                Image(systemName: "arrow.down.to.line.compact")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .keiInteractiveGlass(16)
        .disabled(PasteboardWriter.currentString() == nil)
        .help(L10n.pasteFromClipboard)
        .accessibilityLabel(L10n.pasteFromClipboard)
    }

    private var normalizedID: Int? {
        PixivIDInput.normalizedID(from: rawID)
    }

    @ViewBuilder
    private var nativeDropTarget: some View {
        #if os(macOS)
        CustomDropTarget(
            acceptedTypes: [.url, .plainText, .utf8PlainText],
            onDrop: handleNativeDrop,
            onDragEntered: nil,
            onDragExited: nil
        ) {
            HStack(spacing: 8) {
                Image(systemName: "link.badge.plus")
                    .foregroundStyle(.secondary)

                Text(L10n.dropPixivLinkToOpen)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .keiInteractiveGlass(14)
        }
        #endif
    }

    private func openID() {
        guard let id = normalizedID else { return }
        let openTarget = target
        prepareForOpen()

        Task {
            store.errorMessage = nil
            let message = await store.openPixivID(id, target: openTarget)
            if store.errorMessage == nil {
                showStatus(message)
                dismiss()
            }
        }
    }

    /// "Paste from Clipboard" pulls whatever string is on the pasteboard
    /// and figures out the best `target / id` pairing the user is most
    /// likely after. We try, in order:
    ///
    ///   1. `PixivIDQuickOpenParser` — `illust:123`, `user:456`, etc.
    ///   2. `PixivWebLinkResolver` — full Pixiv URLs / pixiv.me / app
    ///      scheme links.
    ///   3. Bare digits — fall back to the current target so the user
    ///      can paste a number and just hit Open.
    ///
    /// Whichever path matches, we always populate `rawID` with a clean
    /// numeric string so the existing input field handling stays
    /// uniform and the action button enables itself via `normalizedID`.
    private func pasteFromClipboard() {
        guard let raw = PasteboardWriter.currentString() else { return }

        _ = applyQuickOpenInput(raw, fallbackToRawText: true)
    }

    #if os(macOS)
    private func handleNativeDrop(_ payloads: [NativeDropPayload]) -> Bool {
        for payload in payloads where applyQuickOpenInput(payload.rawText, fallbackToRawText: false) {
            return true
        }

        showStatus(L10n.unsupportedPixivLink)
        return false
    }
    #endif

    @discardableResult
    private func applyQuickOpenInput(_ raw: String, fallbackToRawText: Bool) -> Bool {
        if let request = PixivIDQuickOpenParser.request(from: raw) {
            target = request.target
            rawID = String(request.id)
            return true
        }

        if let url = URL(string: raw),
           let destination = PixivWebLinkResolver.destination(from: url) {
            switch destination {
            case .artwork(let id):
                target = .artwork
                rawID = String(id)
                return true
            case .user(let id):
                target = .creator
                rawID = String(id)
                return true
            case .novel, .novelSeries, .collection, .tag, .search, .creatorSearch, .pixivisionArticle:
                break
            }
        }

        if let webDestination = PixivWebLinkResolver.firstDestination(in: raw) {
            switch webDestination {
            case .artwork(let id):
                target = .artwork
                rawID = String(id)
                return true
            case .user(let id):
                target = .creator
                rawID = String(id)
                return true
            case .novel, .novelSeries, .collection, .tag, .search, .creatorSearch, .pixivisionArticle:
                break
            }
        }

        if PixivIDInput.normalizedID(from: raw) != nil {
            rawID = raw
            return true
        }

        guard fallbackToRawText else {
            return false
        }

        rawID = raw
        return true
    }
}

private struct PixivIDOpenSheetLayout: Equatable {
    let size: CGSize
    let platform: ReaderPlatformKind

    var isCompact: Bool {
        platform == .phone || validWidth < 520
    }

    var contentSpacing: CGFloat {
        isCompact ? 14 : 18
    }

    var contentInsets: EdgeInsets {
        EdgeInsets(
            top: isCompact ? 16 : 20,
            leading: isCompact ? 16 : 20,
            bottom: isCompact ? 18 : 20,
            trailing: isCompact ? 16 : 20
        )
    }

    var footerInsets: EdgeInsets {
        EdgeInsets(
            top: isCompact ? 12 : 14,
            leading: isCompact ? 16 : 20,
            bottom: isCompact ? 12 : 14,
            trailing: isCompact ? 16 : 20
        )
    }

    private var validWidth: CGFloat {
        guard size.width.isFinite, size.width > 0 else { return 0 }
        return size.width
    }

    #if os(iOS)
    static var mobilePresentationDetents: Set<PresentationDetent> {
        [.height(420), .medium, .large]
    }
    #endif
}
