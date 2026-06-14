import SwiftUI

struct BatchDownloadPopover: View {
    @Binding var limit: Int
    @Binding var includeNextPages: Bool
    @Binding var remotePageLimit: Int
    let plan: BatchDownloadPlan
    let queuedCount: Int?
    let isGatheringPages: Bool
    let downloadDestinationSummary: ArtworkDownloadDestinationSummary
    let action: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label(L10n.batchDownload, systemImage: downloadDestinationSummary.systemImage)
                    .font(.headline)
                Text(downloadDestinationSummary.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Stepper(value: $limit, in: 1...plan.maxLimit) {
                LabeledContent(L10n.maximumDownloads, value: "\(limit)")
            }

            if plan.allowsRemotePages {
                Divider()

                Toggle(isOn: $includeNextPages) {
                    Label(L10n.includeFollowingPages, systemImage: "arrow.down.forward.and.arrow.up.backward")
                }

                if includeNextPages {
                    Stepper(value: $remotePageLimit, in: 1...BatchDownloadPlan.maximumRemotePageLimit) {
                        LabeledContent(L10n.followingPageRequests, value: "\(remotePageLimit)")
                    }

                    Text(String(format: L10n.batchDownloadFollowingPagesHintFormat, plan.estimatedRemotePageRequests))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let queuedCount {
                Text(String(format: L10n.queuedDownloadsFormat, queuedCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button {
                    Task { await action() }
                } label: {
                    if isGatheringPages {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.addToDownloadQueue, systemImage: "arrow.down.circle")
                    }
                }
                .buttonStyle(.glassProminent)
                .disabled(isGatheringPages)
            }
        }
        .padding(16)
        .frame(width: 340)
        .onAppear {
            limit = min(max(1, limit), plan.maxLimit)
            remotePageLimit = min(
                max(1, remotePageLimit),
                BatchDownloadPlan.maximumRemotePageLimit
            )
        }
    }
}

struct BulkMutePreviewPopover: View {
    let preview: BulkMutePreview
    let cancel: () -> Void
    let apply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label(preview.target.title, systemImage: preview.target.systemImage)
                    .font(.headline)

                Text(String(format: L10n.bulkMuteAffectedArtworkFormat, preview.affectedArtworkCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if preview.entries.isEmpty {
                OS26InlineUnavailableView(
                    title: L10n.noBulkMuteCandidates,
                    systemImage: "eye.slash",
                    minHeight: 160
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(preview.entries) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.callout.weight(.medium))
                                    .lineLimit(1)

                                if let detail = entry.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .keiGlass(12)
                        }

                        if preview.omittedEntryCount > 0 {
                            Text(String(format: L10n.moreBulkMuteItemsFormat, preview.omittedEntryCount))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            Divider()

            HStack(spacing: 8) {
                Button(L10n.cancel, action: cancel)
                    .os26GlassButton()

                Spacer()

                Button(role: .destructive) {
                    apply()
                } label: {
                    Label(L10n.applyBulkMute, systemImage: "eye.slash")
                }
                .os26GlassButton(prominent: true)
                .disabled(preview.canApply == false)
            }
        }
        .padding(16)
        .frame(width: 340)
    }
}
