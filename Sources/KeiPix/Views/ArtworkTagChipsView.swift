import SwiftUI

struct ArtworkTagChipsView: View {
    let tags: [PixivTag]
    @Bindable var store: KeiPixStore

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.self) { tag in
                tagChip(tag)
            }
        }
    }

    private func tagChip(_ tag: PixivTag) -> some View {
        Button {
            search(tag)
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(tag.name)")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                if let translatedName = translatedName(for: tag) {
                    Text(translatedName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.quinary, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help(tagHelp(tag))
        .contextMenu {
            Button(L10n.searchTag) {
                search(tag)
            }

            Divider()

            Button(L10n.copyTag) {
                PasteboardWriter.copy(tag.name)
            }

            if let translatedName = translatedName(for: tag) {
                Button(L10n.copyTranslatedTag) {
                    PasteboardWriter.copy(translatedName)
                }
            }

            Divider()

            Button(L10n.muteTag) {
                store.muteTag(tag)
            }
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
}
