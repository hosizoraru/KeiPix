import SwiftUI

struct DownloadsSettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator

    var body: some View {
        OS26SettingsPage(
            title: L10n.downloads,
            subtitle: L10n.downloadNamingTemplateHint,
            systemImage: SettingsCategory.downloads.systemImage
        ) {
            folderSection
            queueSection
            namingSection
        }
    }

    private var folderSection: some View {
        OS26SettingsSection(L10n.downloadFolder, systemImage: "folder", footer: nil) {
            LabeledContent(L10n.downloadFolder) {
                Text(store.downloads.downloadDirectoryPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            FlowLayout(spacing: 8) {
                Button {
                    if store.downloads.chooseDownloadDirectory() {
                        coordinator.setActionMessage(L10n.downloadFolderChanged)
                    }
                } label: {
                    Label(L10n.chooseFolder, systemImage: "folder.badge.gearshape")
                }
                .os26GlassButton(prominent: true)

                Button {
                    coordinator.setActionMessage(
                        store.downloads.openDownloadDirectory()
                            ? L10n.openedDownloadFolder
                            : L10n.unableToOpenDownloadFolder
                    )
                } label: {
                    Label(L10n.openFolder, systemImage: "folder")
                }
                .os26GlassButton()
            }
        }
    }

    private var queueSection: some View {
        OS26SettingsSection(
            L10n.concurrentDownloads,
            systemImage: "arrow.down.to.line.compact",
            footer: "\(L10n.concurrentDownloadsHint)\n\(L10n.autoBookmarkDownloadedArtworksHint)\n\(L10n.notifyOnDownloadFinishHint)"
        ) {
            Stepper(
                value: store.settings_maxConcurrentDownloadsBinding,
                in: 1...4,
                step: 1
            ) {
                LabeledContent(L10n.concurrentDownloads) {
                    Text(store.downloads.maxConcurrentDownloads.formatted())
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(L10n.autoBookmarkDownloadedArtworks, isOn: store.settings_autoBookmarkDownloadsBinding)

            Toggle(L10n.notifyOnDownloadFinish, isOn: store.settings_notifyOnDownloadFinishBinding)
        }
    }

    private var namingSection: some View {
        OS26SettingsSection(
            L10n.downloadNamingTemplate,
            systemImage: "textformat.abc",
            footer: L10n.downloadNamingTemplateHint
        ) {
            OS26LibraryTextEntryField(
                text: store.settings_downloadNamingTemplateBinding,
                placeholder: L10n.downloadNamingTemplate
            )
                .font(.system(.body, design: .monospaced))

            // Live preview rows. Each scenario renders the user's current
            // template against a documented sample (standalone / multi-
            // page / serialized manga) so a token swap shows up
            // immediately instead of surfacing on the next download. We
            // prefix each row with the absolute download folder so users
            // see exactly where the file will land — Pixez and Pixes
            // both stop at the relative path, which hid surprising
            // double-folder layouts during P2 dogfooding.
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.livePreview)
                    .font(.subheadline.weight(.semibold))
                ForEach(store.downloads.downloadNamingTemplatePreviewScenarios) { scenario in
                    previewRow(scenario: scenario)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Surface unknown placeholders next to the field so a typo
            // like ${ide} doesn't silently collapse to an empty string at
            // download time. Empty list path is silent.
            let unknown = store.downloads.unknownNamingPlaceholders
            if unknown.isEmpty == false {
                VStack(alignment: .leading, spacing: 4) {
                    Label {
                        Text(L10n.unknownPlaceholdersFormat(unknown.joined(separator: ", ")))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    .font(.callout)
                    Text(L10n.unknownPlaceholdersHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                coordinator.setActionMessage(
                    store.downloads.resetDownloadNamingTemplate()
                        ? L10n.downloadTemplateReset
                        : L10n.downloadTemplateAlreadyDefault
                )
            } label: {
                Label(L10n.resetTemplate, systemImage: "arrow.counterclockwise")
            }
            .os26GlassButton()
        }
    }

    private func previewRow(scenario: DownloadNamingTemplate.PreviewScenario) -> some View {
        // Compose the absolute path manually rather than via NSString
        // pathComponents so the trailing slash from the download folder
        // never produces a doubled separator on the rendered relative
        // path's leading slash (the template renderer already returns a
        // path without a leading slash, but a user-supplied folder might
        // arrive either way).
        let folder = store.downloads.downloadDirectoryPath
        let trimmedFolder = folder.hasSuffix("/") ? String(folder.dropLast()) : folder
        let relative = scenario.renderedPath
        let absolute = relative.hasPrefix("/") ? "\(trimmedFolder)\(relative)" : "\(trimmedFolder)/\(relative)"
        return VStack(alignment: .leading, spacing: 2) {
            Text(label(for: scenario.id))
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Text(absolute)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private func label(for kind: DownloadNamingTemplate.PreviewScenarioKind) -> String {
        switch kind {
        case .standalone: return L10n.templatePreviewStandalone
        case .multiPage: return L10n.templatePreviewMultiPage
        case .series: return L10n.templatePreviewSeries
        }
    }
}
