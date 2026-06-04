import SwiftUI

/// One-shot block flow for an artwork.
///
/// Mirrors Pixes' "Blocking" page where the user picks any combination of the
/// artwork itself, its author, and its tags and blocks them all in a single
/// gesture. The mutes land in the local mute store (the same path used by
/// the per-tag context menu and the per-artwork mute confirmation), so the
/// outcome is the same as taking each action one at a time, just faster.
struct BulkBlockSheet: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    let onComplete: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var blockArtwork = false
    @State private var blockCreator = false
    @State private var blockedTags: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.blockFromArtwork)
                        .font(.title3.weight(.semibold))
                    Text(L10n.blockSelectedHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                SheetCloseButton(style: .plain)
            }

            Form {
                Section {
                    Toggle(L10n.blockArtworkOption, isOn: $blockArtwork)
                    Toggle(
                        String(format: "\(L10n.blockCreatorOption) (%@)", artwork.user.name),
                        isOn: $blockCreator
                    )
                }

                if artwork.tags.isEmpty == false {
                    Section(L10n.blockTagsHeader) {
                        ForEach(artwork.tags, id: \.self) { tag in
                            Toggle(
                                tagLabel(for: tag),
                                isOn: tagBinding(for: tag)
                            )
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 220)

            Divider()

            HStack {
                if totalSelectedCount == 0 {
                    Text(L10n.bulkBlockNothingSelected)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(L10n.cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    applyBlocks()
                } label: {
                    Label(L10n.blockSelected, systemImage: "hand.raised.fill")
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .keyboardShortcut(.defaultAction)
                .disabled(totalSelectedCount == 0)
            }
        }
        .padding(22)
        #if os(macOS)
        .frame(width: 460)
        #endif
    }

    private var totalSelectedCount: Int {
        (blockArtwork ? 1 : 0) + (blockCreator ? 1 : 0) + blockedTags.count
    }

    private func tagLabel(for tag: PixivTag) -> String {
        if store.showTranslatedTags,
           let translated = tag.translatedName?.trimmingCharacters(in: .whitespacesAndNewlines),
           translated.isEmpty == false,
           translated.localizedCaseInsensitiveCompare(tag.name) != .orderedSame {
            return "#\(tag.name) · \(translated)"
        }
        return "#\(tag.name)"
    }

    private func tagBinding(for tag: PixivTag) -> Binding<Bool> {
        Binding {
            blockedTags.contains(tag.name)
        } set: { value in
            if value {
                blockedTags.insert(tag.name)
            } else {
                blockedTags.remove(tag.name)
            }
        }
    }

    private func applyBlocks() {
        var applied = 0

        if blockArtwork {
            store.muteArtwork(artwork)
            applied += 1
        }
        if blockCreator {
            store.muteUser(artwork.user)
            applied += 1
        }
        for tagName in blockedTags {
            store.muteTag(named: tagName)
            applied += 1
        }

        onComplete(applied)
        dismiss()
    }
}
