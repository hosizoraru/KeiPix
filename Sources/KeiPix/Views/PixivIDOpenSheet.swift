import SwiftUI

struct PixivIDOpenSheet: View {
    @Bindable var store: KeiPixStore
    let showStatus: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var target: PixivIDOpenTarget = .artwork
    @State private var rawID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeaderRail(
                overline: L10n.openPixivID,
                title: L10n.openPixivIDTarget,
                subtitle: L10n.openPixivIDHint,
                leading: {
                    SheetHeaderIcon(systemImage: "number", tint: .accentColor)
                },
                trailing: {
                    SheetHeaderActionButton(
                        title: L10n.pasteFromClipboard,
                        systemImage: "doc.on.clipboard",
                        action: pasteFromClipboard,
                        isDisabled: PasteboardWriter.currentString() == nil
                    )
                }
            )

            Divider()

            VStack(alignment: .leading, spacing: 18) {
                Picker(L10n.openPixivIDTarget, selection: $target) {
                    ForEach(PixivIDOpenTarget.allCases) { option in
                        Label(option.title, systemImage: option.systemImage)
                            .tag(option)
                    }
                }
                .pickerStyle(.segmented)

                TextField(target.placeholder, text: $rawID)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3.monospacedDigit())
                    .onSubmit(openID)

                Text(L10n.pixivIDQuickOpenHint)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(20)

            Spacer(minLength: 0)

            Divider()

            HStack {
                Button(L10n.cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button {
                    openID()
                } label: {
                    Label(L10n.open, systemImage: target.systemImage)
                }
                .buttonStyle(.glassProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(normalizedID == nil)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: 460)
    }

    private var normalizedID: Int? {
        PixivIDInput.normalizedID(from: rawID)
    }

    private func openID() {
        guard let id = normalizedID else { return }

        Task {
            let message = await store.openPixivID(id, target: target)
            showStatus(message)
            dismiss()
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

        if let request = PixivIDQuickOpenParser.request(from: raw) {
            target = request.target
            rawID = String(request.id)
            return
        }

        if let url = URL(string: raw),
           let destination = PixivWebLinkResolver.destination(from: url) {
            switch destination {
            case .artwork(let id):
                target = .artwork
                rawID = String(id)
                return
            case .user(let id):
                target = .creator
                rawID = String(id)
                return
            case .tag, .search, .creatorSearch, .pixivisionArticle:
                break
            }
        }

        if let webDestination = PixivWebLinkResolver.firstDestination(in: raw) {
            switch webDestination {
            case .artwork(let id):
                target = .artwork
                rawID = String(id)
                return
            case .user(let id):
                target = .creator
                rawID = String(id)
                return
            case .tag, .search, .creatorSearch, .pixivisionArticle:
                break
            }
        }

        rawID = raw
    }
}
