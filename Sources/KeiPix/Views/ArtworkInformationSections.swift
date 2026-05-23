import SwiftUI

struct ArtworkInformationSections: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var captionExpanded: Bool
    @Binding var tagsExpanded: Bool
    @Binding var metadataExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if artwork.caption.htmlStripped.isEmpty == false {
                CollapsibleInspectorSection(
                    title: L10n.description,
                    systemImage: "text.alignleft",
                    isExpanded: $captionExpanded
                ) {
                    Text(artwork.caption.htmlStripped)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            CollapsibleInspectorSection(
                title: L10n.tags,
                systemImage: "tag",
                isExpanded: $tagsExpanded
            ) {
                ArtworkTagChipsView(tags: artwork.tags, store: store)
            }

            CollapsibleInspectorSection(
                title: L10n.artworkInformation,
                systemImage: "info.circle",
                isExpanded: $metadataExpanded
            ) {
                DetailMetadata(artwork: artwork)
            }
        }
    }
}

private struct CollapsibleInspectorSection<Content: View>: View {
    let title: String
    let systemImage: String
    @Binding var isExpanded: Bool
    @ViewBuilder var content: Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
                .padding(.top, 10)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .disclosureGroupStyle(.automatic)
        .padding(14)
        .keiPanel(16)
    }
}

private struct DetailMetadata: View {
    let artwork: PixivArtwork

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
            GridRow {
                Text(L10n.artworkID)
                    .foregroundStyle(.secondary)
                Text("\(artwork.id)")
                    .textSelection(.enabled)
            }
            GridRow {
                Text(L10n.creatorID)
                    .foregroundStyle(.secondary)
                Text("\(artwork.user.id)")
                    .textSelection(.enabled)
            }
            GridRow {
                Text(L10n.created)
                    .foregroundStyle(.secondary)
                Text(artwork.createDate.formatted(date: .abbreviated, time: .shortened))
            }
            GridRow {
                Text(L10n.contentRating)
                    .foregroundStyle(.secondary)
                Text(contentRating)
            }
            GridRow {
                Text(L10n.aiGenerated)
                    .foregroundStyle(.secondary)
                Text(artwork.isAI ? L10n.yes : L10n.no)
            }
        }
        .font(.caption)
    }

    private var contentRating: String {
        if artwork.isR18G {
            return L10n.r18g
        }
        if artwork.isR18 {
            return L10n.r18
        }
        return L10n.allAges
    }
}
