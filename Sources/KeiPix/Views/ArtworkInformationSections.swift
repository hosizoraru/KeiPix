import SwiftUI

struct ArtworkInformationSections: View {
    let artwork: PixivArtwork
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
                FlowLayout(spacing: 8) {
                    ForEach(artwork.tags, id: \.self) { tag in
                        Text(tag.translatedName.map { "#\(tag.name) / \($0)" } ?? "#\(tag.name)")
                            .font(.caption)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .foregroundStyle(.secondary)
                            .background(.quinary, in: Capsule())
                    }
                }
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
        }
        .font(.caption)
    }
}
