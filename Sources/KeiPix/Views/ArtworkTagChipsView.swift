import SwiftUI

struct ArtworkTagChipsView: View {
    let tags: [PixivTag]
    @Bindable var store: KeiPixStore
    @State private var actionMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    tagChip(tag)
                }
            }

            if let actionMessage {
                Text(actionMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .animation(.snappy(duration: 0.18), value: actionMessage)
    }

    private func tagChip(_ tag: PixivTag) -> some View {
        Button {
            search(tag)
        } label: {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 5) {
                    tagTitle(tag)
                    translatedTagTitle(tag)
                    Image(systemName: "magnifyingglass")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        tagTitle(tag)
                        Image(systemName: "magnifyingglass")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    translatedTagTitle(tag)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .contentShape(ButtonBorderShape.roundedRectangle(radius: 13))
            .keiInteractiveGlass(13)
        }
        .buttonStyle(.plain)
        .help(tagHelp(tag))
        .accessibilityLabel(tagHelp(tag))
        .contextMenu {
            Button(L10n.searchTag) {
                search(tag)
            }

            if let url = PixivWebURLBuilder.tagURL(tagName: tag.name) {
                Link(destination: url) {
                    Label(L10n.openTagInPixiv, systemImage: "safari")
                }

                Button {
                    PasteboardWriter.copy(url.absoluteString)
                    showActionMessage(L10n.copied)
                } label: {
                    Label(L10n.copyTagLink, systemImage: "link")
                }
            }

            Divider()

            Button(L10n.copyTag) {
                PasteboardWriter.copy(tag.name)
                showActionMessage(String(format: L10n.copiedKeywordFormat, "#\(tag.name)"))
            }

            if let translatedName = translatedName(for: tag) {
                Button(L10n.copyTranslatedTag) {
                    PasteboardWriter.copy(translatedName)
                    showActionMessage(String(format: L10n.copiedKeywordFormat, translatedName))
                }
            }

            Divider()

            Button(L10n.muteTag) {
                store.requestDangerAction(AppDangerAction(kind: .muteTag(tag)))
            }
        }
    }

    private func tagTitle(_ tag: PixivTag) -> some View {
        Text("#\(tag.name)")
            .font(.caption.weight(.semibold))
            .lineLimit(1)
    }

    @ViewBuilder
    private func translatedTagTitle(_ tag: PixivTag) -> some View {
        if let translatedName = translatedName(for: tag) {
            Text(translatedName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func translatedName(for tag: PixivTag) -> String? {
        guard store.showTranslatedTags,
              let translatedName = tag.translatedName?.trimmingCharacters(in: .whitespacesAndNewlines),
              translatedName.isEmpty == false,
              translatedName.localizedCaseInsensitiveCompare(tag.name) != .orderedSame else {
            return nil
        }
        return translatedName
    }

    private func tagHelp(_ tag: PixivTag) -> String {
        if let translatedName = translatedName(for: tag) {
            return "#\(tag.name) / \(translatedName)"
        }
        return "#\(tag.name)"
    }

    private func search(_ tag: PixivTag) {
        store.searchText = tag.name
        Task { await store.runSearch() }
    }

    private func showActionMessage(_ message: String) {
        actionMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            if actionMessage == message {
                actionMessage = nil
            }
        }
    }
}
