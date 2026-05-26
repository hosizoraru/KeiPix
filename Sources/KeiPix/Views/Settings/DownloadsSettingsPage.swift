import SwiftUI

struct DownloadsSettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator

    var body: some View {
        Form {
            folderSection
            queueSection
            namingSection
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.downloads)
    }

    private var folderSection: some View {
        Section {
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

                Button {
                    coordinator.setActionMessage(
                        store.downloads.openDownloadDirectory()
                            ? L10n.openedDownloadFolder
                            : L10n.unableToOpenDownloadFolder
                    )
                } label: {
                    Label(L10n.openFolder, systemImage: "folder")
                }
            }
        } header: {
            Text(L10n.downloadFolder)
        }
    }

    private var queueSection: some View {
        Section {
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
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.concurrentDownloadsHint)
                Text(L10n.autoBookmarkDownloadedArtworksHint)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var namingSection: some View {
        Section {
            TextField(L10n.downloadNamingTemplate, text: store.settings_downloadNamingTemplateBinding)
                .textFieldStyle(.roundedBorder)

            LabeledContent(L10n.templatePreview) {
                Text(store.downloads.downloadNamingTemplatePreview)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
        } header: {
            Text(L10n.downloadNamingTemplate)
        } footer: {
            Text(L10n.downloadNamingTemplateHint)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
