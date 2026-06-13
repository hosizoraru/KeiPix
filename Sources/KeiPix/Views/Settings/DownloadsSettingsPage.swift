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
            templateEditor

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

    private var templateEditor: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                templateTextField
                    .layoutPriority(1)
                presetMenu
                tokenMenu
            }

            VStack(alignment: .leading, spacing: 10) {
                templateTextField
                HStack(spacing: 8) {
                    presetMenu
                    tokenMenu
                }
            }
        }
    }

    private var templateTextField: some View {
        OS26LibraryTextEntryField(
            text: store.settings_downloadNamingTemplateBinding,
            placeholder: L10n.downloadNamingTemplate
        )
        .font(.system(.body, design: .monospaced))
    }

    private var tokenMenu: some View {
        Menu {
            ForEach(DownloadNamingTemplate.TokenGroup.allCases) { group in
                Section(tokenGroupTitle(group)) {
                    ForEach(tokens(in: group)) { token in
                        Button {
                            insertTemplateToken(token)
                        } label: {
                            Label(
                                "\(token.placeholder) · \(tokenTitle(token))",
                                systemImage: tokenIcon(token)
                            )
                        }
                    }
                }
            }
        } label: {
            Label(L10n.insertTemplateToken, systemImage: "curlybraces.square")
                .lineLimit(1)
        }
        .os26GlassButton()
        .fixedSize(horizontal: true, vertical: false)
        .help(L10n.insertTemplateToken)
        .accessibilityLabel(L10n.insertTemplateToken)
    }

    private var presetMenu: some View {
        Menu {
            ForEach(DownloadNamingTemplate.documentedPresets) { preset in
                Button {
                    applyTemplatePreset(preset)
                } label: {
                    Label(presetTitle(preset), systemImage: presetIcon(preset))
                }
            }
        } label: {
            Label(L10n.applyTemplatePreset, systemImage: "wand.and.stars")
                .lineLimit(1)
        }
        .os26GlassButton()
        .fixedSize(horizontal: true, vertical: false)
        .help(L10n.applyTemplatePreset)
        .accessibilityLabel(L10n.applyTemplatePreset)
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

    private func tokens(in group: DownloadNamingTemplate.TokenGroup) -> [DownloadNamingTemplate.Token] {
        DownloadNamingTemplate.documentedTokens.filter { $0.group == group }
    }

    private func insertTemplateToken(_ token: DownloadNamingTemplate.Token) {
        let current = store.downloads.downloadNamingTemplate
        let separator: String
        if current.isEmpty || current.hasSuffix("/") || current.hasSuffix("_") || current.hasSuffix("-") || current.hasSuffix(" ") {
            separator = ""
        } else {
            separator = "_"
        }
        store.downloads.setDownloadNamingTemplate("\(current)\(separator)\(token.placeholder)")
        coordinator.setActionMessage(L10n.insertedTemplateToken(token.placeholder))
    }

    private func applyTemplatePreset(_ preset: DownloadNamingTemplate.Preset) {
        let title = presetTitle(preset)
        store.downloads.setDownloadNamingTemplate(preset.template)
        coordinator.setActionMessage(
            String(format: L10n.templatePresetAppliedFormat, locale: Locale.current, title)
        )
    }

    private func tokenGroupTitle(_ group: DownloadNamingTemplate.TokenGroup) -> String {
        switch group {
        case .identity: return L10n.works
        case .creator: return L10n.creator
        case .series: return L10n.series
        case .page: return L10n.pages
        case .flags: return L10n.templateTokenFlags
        case .tags: return L10n.tags
        }
    }

    private func presetTitle(_ preset: DownloadNamingTemplate.Preset) -> String {
        switch preset.id {
        case .default: return L10n.defaultLabel
        case .creator: return L10n.creator
        case .series: return L10n.series
        case .tagged: return L10n.tags
        }
    }

    private func presetIcon(_ preset: DownloadNamingTemplate.Preset) -> String {
        switch preset.id {
        case .default: return "doc.badge.gearshape"
        case .creator: return "person.crop.circle"
        case .series: return "books.vertical"
        case .tagged: return "tag"
        }
    }

    private func tokenTitle(_ token: DownloadNamingTemplate.Token) -> String {
        switch token.key {
        case "id": return "ID"
        case "title": return L10n.title
        case "user": return L10n.creator
        case "userId": return L10n.creatorID
        case "series": return L10n.series
        case "seriesId": return L10n.seriesID
        case "page": return L10n.pageIndex
        case "page1": return L10n.page
        case "pages": return L10n.pages
        case "ext": return L10n.fileExtension
        case "AI": return L10n.aiGenerated
        case "R18": return L10n.r18
        case "R18G": return L10n.r18g
        case "tag1": return L10n.firstTag
        case "tag2": return L10n.secondTag
        case "tag(name)": return L10n.namedTag
        default: return token.displayName
        }
    }

    private func tokenIcon(_ token: DownloadNamingTemplate.Token) -> String {
        switch token.group {
        case .identity: return "photo"
        case .creator: return "person.crop.circle"
        case .series: return "books.vertical"
        case .page: return "doc.on.doc"
        case .flags: return "flag"
        case .tags: return "tag"
        }
    }
}
