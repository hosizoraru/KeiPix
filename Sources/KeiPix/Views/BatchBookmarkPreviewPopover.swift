import SwiftUI

struct BatchBookmarkPreviewPopover: View {
    let preview: BatchBookmarkPreview
    let isApplying: Bool
    let cancel: () -> Void
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            tagChips
            candidatesSection
            skippedSection
            footer
        }
        .padding(16)
        .frame(width: 400)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(L10n.batchBookmark, systemImage: "bookmark")
                .font(.headline)

            Text(String(format: L10n.batchBookmarkScopeFormat, preview.scope.title, preview.sourceArtworkCount))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                String(
                    format: L10n.batchBookmarkPreviewFormat,
                    preview.applyArtworks.count,
                    preview.skippedBookmarked.count,
                    preview.restrict.title
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var tagChips: some View {
        if preview.tags.isEmpty == false {
            FlowLayout(spacing: 6) {
                ForEach(preview.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular, in: Capsule(style: .continuous))
                }
            }
        }
    }

    @ViewBuilder
    private var candidatesSection: some View {
        if preview.applyArtworks.isEmpty {
            ContentUnavailableView(preview.scope.emptyStateTitle, systemImage: "bookmark")
                .frame(minHeight: 150)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(preview.applyArtworks.prefix(10)) { artwork in
                        BatchBookmarkArtworkRow(artwork: artwork, isSkipped: false)
                    }

                    if preview.omittedCandidateCount > 0 {
                        Text(String(format: L10n.moreBatchBookmarkItemsFormat, preview.omittedCandidateCount))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                    }
                }
            }
            .frame(maxHeight: 250)
        }
    }

    @ViewBuilder
    private var skippedSection: some View {
        if preview.skippedBookmarked.isEmpty == false {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    String(format: L10n.batchBookmarkSkippedFormat, preview.skippedBookmarked.count),
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                ForEach(preview.skippedBookmarkedPreview) { artwork in
                    BatchBookmarkArtworkRow(artwork: artwork, isSkipped: true)
                }

                if preview.omittedSkippedBookmarkedCount > 0 {
                    Text(String(format: L10n.moreSkippedBatchBookmarkItemsFormat, preview.omittedSkippedBookmarkedCount))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Divider()

            HStack(spacing: 8) {
                Button(L10n.cancel, action: cancel)
                    .disabled(isApplying)

                Spacer()

                Button {
                    apply()
                } label: {
                    if isApplying {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.applyBookmarks, systemImage: "bookmark.fill")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(preview.canApply == false || isApplying)
            }
        }
    }
}

private struct BatchBookmarkArtworkRow: View {
    let artwork: PixivArtwork
    let isSkipped: Bool

    var body: some View {
        HStack(spacing: 8) {
            RemoteImageView(url: artwork.thumbnailURL)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .opacity(isSkipped ? 0.55 : 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(artwork.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(artwork.user.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if isSkipped {
                Spacer(minLength: 8)
                Text(L10n.skipped)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var rowBackground: AnyShapeStyle {
        isSkipped ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.thinMaterial)
    }
}
