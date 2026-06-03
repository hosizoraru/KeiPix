import SwiftUI

struct ArtworkInformationSections: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var captionExpanded: Bool
    @Binding var tagsExpanded: Bool
    @Binding var metadataExpanded: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ArtworkContextCard(
                artwork: artwork,
                store: store,
                isExpanded: contextExpansionBinding
            )

            TagCloudInspectorSection(
                artwork: artwork,
                store: store,
                isExpanded: $tagsExpanded
            )
        }
    }

    private var contextExpansionBinding: Binding<Bool> {
        Binding {
            captionExpanded || metadataExpanded
        } set: { value in
            captionExpanded = value
            metadataExpanded = value
        }
    }
}

private struct ArtworkContextCard: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                if artwork.caption.htmlStripped.isEmpty == false {
                    captionBlock
                }

                ArtworkMetadataRail(artwork: artwork)
            }
            .padding(.top, 10)
        } label: {
            ArtworkInspectorSectionHeader(
                title: L10n.artworkInformation,
                subtitle: headerSubtitle,
                systemImage: "doc.text.magnifyingglass"
            )
        }
        .disclosureGroupStyle(.automatic)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .keiGlass(18)
    }

    private var captionBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(L10n.description, systemImage: "text.alignleft")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            InlineTranslateSection(text: artwork.caption.htmlStripped, translationTargetLanguage: store.translationTargetLanguage) {
                Text(artwork.caption.htmlStripped)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var headerSubtitle: String {
        [
            "#\(artwork.id)",
            artwork.displayPageCount > 1 ? L10n.pageCountShort(artwork.displayPageCount) : nil,
            contentRating
        ]
        .compactMap { $0 }
        .joined(separator: " · ")
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

private struct TagCloudInspectorSection: View {
    let artwork: PixivArtwork
    @Bindable var store: KeiPixStore
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ArtworkTagChipsView(tags: artwork.tags, store: store)
                .padding(.top, 10)
        } label: {
            ArtworkInspectorSectionHeader(
                title: L10n.tags,
                subtitle: String(format: L10n.tagCountFormat, artwork.tags.count),
                systemImage: "tag"
            )
        }
        .disclosureGroupStyle(.automatic)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .keiGlass(18)
    }
}

struct ArtworkInspectorSectionHeader: View {
    let title: String
    let subtitle: String?
    let systemImage: String

    var body: some View {
        Label {
            HStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)

                if let subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .glassEffect(.regular, in: Capsule(style: .continuous))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ArtworkMetadataRail: View {
    let artwork: PixivArtwork

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { item in
                ArtworkMetadataPill(item: item)
            }
        }
    }

    private var items: [ArtworkMetadataItem] {
        [
            ArtworkMetadataItem(
                id: "created",
                title: L10n.created,
                value: artwork.createDate.formatted(date: .abbreviated, time: .shortened),
                systemImage: "calendar"
            ),
            artworkSizeItem,
            ArtworkMetadataItem(
                id: "pages",
                title: L10n.pages,
                value: "\(artwork.displayPageCount)",
                systemImage: "square.stack"
            ),
            ArtworkMetadataItem(
                id: "rating",
                title: L10n.contentRating,
                value: contentRating,
                systemImage: "shield"
            ),
            ArtworkMetadataItem(
                id: "ai",
                title: L10n.aiGenerated,
                value: artwork.isAI ? L10n.yes : L10n.no,
                systemImage: artwork.isAI ? "sparkles" : "checkmark.seal"
            ),
            ArtworkMetadataItem(
                id: "artwork-id",
                title: L10n.artworkID,
                value: "\(artwork.id)",
                systemImage: "number"
            ),
            ArtworkMetadataItem(
                id: "creator-id",
                title: L10n.creatorID,
                value: "\(artwork.user.id)",
                systemImage: "person.crop.square"
            )
        ]
        .compactMap { $0 }
    }

    private var artworkSizeItem: ArtworkMetadataItem? {
        guard artwork.width > 0, artwork.height > 0 else { return nil }
        return ArtworkMetadataItem(
            id: "size",
            title: L10n.imageSize,
            value: "\(artwork.width) x \(artwork.height)",
            systemImage: "aspectratio"
        )
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

private struct ArtworkMetadataItem: Identifiable {
    let id: String
    let title: String
    let value: String
    let systemImage: String
}

private struct ArtworkMetadataPill: View {
    let item: ArtworkMetadataItem

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(item.value)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        } icon: {
            Image(systemName: item.systemImage)
                .foregroundStyle(.secondary)
        }
        .labelStyle(.titleAndIcon)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .fixedSize(horizontal: true, vertical: false)
    }
}
