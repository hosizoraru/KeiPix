import SwiftUI

struct SettingsView: View {
    @Bindable var store: KeiPixStore
    @State private var isSyncingMutedContent = false
    @State private var isUpdatingRestrictedMode = false
    @State private var mutedContentSyncMessage: String?
    @State private var mutedContentSyncMessageIsError = false
    @State private var restrictedModeMessage: String?
    @State private var settingsActionMessage: String?
    @State private var isLogoutConfirmationPresented = false
    @State private var isAccountLoginPresented = false
    @State private var accountRemovalCandidate: PixivStoredAccount?
    @State private var isMutedContentSyncConfirmationPresented = false
    @State private var isMutedContentUploadConfirmationPresented = false
    @State private var isMutedContentImportConfirmationPresented = false
    @State private var settingsSearchText = ""

    var body: some View {
        Form {
            settingsSearchSection
            generalSettingsSection
            readingSettingsSection
            discoverySettingsSection
            copyTemplateSettingsSection
            safetySettingsSection
            downloadsSettingsSection
            accountSettingsSection
            advancedQASettingsSection
            settingsNoResultsSection
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(minWidth: 560, idealWidth: 620, maxWidth: 720)
        .overlay(alignment: .bottom) {
            VStack(spacing: 8) {
                if let settingsActionMessage {
                    FloatingStatusBanner(maxWidth: 520) {
                        Text(settingsActionMessage)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                if let undoAction = store.undoAction {
                    AppUndoBar(action: undoAction) {
                        Task { await store.performUndo(undoAction) }
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 14)
        }
        .animation(.snappy(duration: 0.18), value: settingsActionMessage)
        .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
        .task(id: settingsActionMessage) {
            await dismissSettingsActionMessageIfNeeded(settingsActionMessage)
        }
        .sheet(isPresented: $isAccountLoginPresented) {
            LoginSheetView(store: store)
                .frame(width: 900, height: 680)
        }
        .confirmationDialog(
            L10n.logout,
            isPresented: $isLogoutConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.logout, role: .destructive) {
                Task { await store.logout() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.logoutConfirmation)
        }
        .confirmationDialog(
            accountRemovalCandidate.map { String(format: L10n.removeAccountConfirmationFormat, $0.name) } ?? L10n.removeAccount,
            isPresented: accountRemovalBinding,
            titleVisibility: .visible,
            presenting: accountRemovalCandidate
        ) { account in
            Button(L10n.removeAccount, role: .destructive) {
                Task {
                    await store.removeStoredAccount(userID: account.id)
                    showSettingsActionMessage(String(format: L10n.removedAccountFormat, account.name))
                }
            }
            Button(L10n.cancel, role: .cancel) {
                accountRemovalCandidate = nil
            }
        } message: { account in
            Text(String(format: L10n.removeAccountConfirmationFormat, account.name))
        }
        .confirmationDialog(
            L10n.syncMutedContentConfirmation,
            isPresented: $isMutedContentSyncConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.syncFromPixiv) {
                Task { await syncMutedContentFromPixiv() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.syncMutedContentConfirmationMessage)
        }
        .confirmationDialog(
            L10n.uploadMutedContentConfirmation,
            isPresented: $isMutedContentUploadConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.uploadToPixiv, role: .destructive) {
                Task { await uploadMutedContentToPixiv() }
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.uploadMutedContentConfirmationMessage)
        }
        .confirmationDialog(
            L10n.importMutedContentConfirmation,
            isPresented: $isMutedContentImportConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L10n.importMutedContent) {
                importLocalMutedContent()
            }
            Button(L10n.cancel, role: .cancel) {}
        } message: {
            Text(L10n.importMutedContentConfirmationMessage)
        }
        .task {
            if store.session != nil, store.restrictedModeEnabled == nil {
                await store.refreshRestrictedModeSetting()
            }
        }
    }

    private var settingsSearchSection: some View {
        Section {
            TextField(L10n.searchSettings, text: $settingsSearchText)
                .textFieldStyle(.roundedBorder)
        }
    }

    @ViewBuilder
    private var generalSettingsSection: some View {
        if settingsMatches(generalSettingsTerms) {
            Section(L10n.settingsGeneral) {
                Picker(L10n.language, selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(L10n.useOriginalImages, isOn: originalBinding)
                Toggle(L10n.showTranslatedTags, isOn: translatedTagsBinding)

                Divider()

                Picker(L10n.galleryLayout, selection: galleryLayoutBinding) {
                    ForEach(GalleryLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var readingSettingsSection: some View {
        if settingsMatches(readingSettingsTerms) {
            Section(L10n.readingWindow) {
                Picker(L10n.defaultArtworkReadingMode, selection: defaultArtworkReadingModeBinding) {
                    ForEach(ArtworkReadingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker(L10n.defaultMangaReadingMode, selection: defaultMangaReadingModeBinding) {
                    ForEach(ArtworkReadingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(L10n.defaultReadingModeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L10n.restoreLastReadPage, isOn: restoreReaderProgressBinding)
                Text(L10n.restoreLastReadPageHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Toggle(L10n.enableTrackpadGestures, isOn: trackpadGesturesBinding)

                Picker(L10n.twoFingerSwipeBehavior, selection: horizontalSwipeBehaviorBinding) {
                    ForEach(TrackpadHorizontalSwipeBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    @ViewBuilder
    private var discoverySettingsSection: some View {
        if settingsMatches(discoverySettingsTerms) {
            Section(L10n.settingsDiscovery) {
                Picker(L10n.defaultBookmarkVisibility, selection: defaultBookmarkRestrictBinding) {
                    ForEach(BookmarkRestrict.allCases) { restrict in
                        Text(restrict.title).tag(restrict)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(L10n.autoTagBookmarksWithArtworkTags, isOn: autoTagBookmarksBinding)
                Text(L10n.autoTagBookmarksWithArtworkTagsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L10n.followCreatorAfterBookmark, isOn: followCreatorAfterBookmarkBinding)
                Text(L10n.followCreatorAfterBookmarkHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L10n.autoDownloadBookmarkedArtworks, isOn: autoDownloadBookmarksBinding)
                Text(L10n.autoDownloadBookmarkedArtworksHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                Picker(L10n.defaultFollowVisibility, selection: defaultFollowRestrictBinding) {
                    ForEach(BookmarkRestrict.allCases) { restrict in
                        Text(restrict.title).tag(restrict)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private var copyTemplateSettingsSection: some View {
        if settingsMatches(copyTemplateSettingsTerms) {
            CopyTemplateSettingsSection(store: store, showMessage: showSettingsActionMessage)
        }
    }

    @ViewBuilder
    private var safetySettingsSection: some View {
        if settingsMatches(safetySettingsTerms) {
            Section(L10n.settingsSafety) {
                Toggle(L10n.showContentBadges, isOn: showContentBadgesBinding)
                Toggle(L10n.hideMutedContent, isOn: hideMutedBinding)
                Toggle(L10n.hideAIArtworks, isOn: hideAIBinding)
                Text(L10n.pixivAIDisplayHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle(L10n.hideR18Artworks, isOn: hideR18Binding)
                Toggle(L10n.hideR18GArtworks, isOn: hideR18GBinding)
                Toggle(L10n.maskSensitivePreviews, isOn: maskSensitivePreviewsBinding)
                Text(L10n.maskSensitivePreviewsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.session != nil {
                    Divider()

                    HStack(spacing: 8) {
                        Toggle(L10n.pixivRestrictedMode, isOn: restrictedModeBinding)
                            .disabled(store.restrictedModeEnabled == nil || isUpdatingRestrictedMode)

                        if store.restrictedModeEnabled == nil || isUpdatingRestrictedMode {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }

                    Text(L10n.pixivRestrictedModeHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let restrictedModeMessage {
                        Text(restrictedModeMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    }
                }

                Divider()

                Text(L10n.muteSyncHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    Button {
                        isMutedContentSyncConfirmationPresented = true
                    } label: {
                        Label(L10n.syncFromPixiv, systemImage: "arrow.down.circle")
                    }
                    .disabled(isSyncingMutedContent)

                    Button {
                        isMutedContentUploadConfirmationPresented = true
                    } label: {
                        Label(L10n.uploadToPixiv, systemImage: "arrow.up.circle")
                    }
                    .disabled(isSyncingMutedContent || (store.mutedTagList.isEmpty && store.mutedUserList.isEmpty))

                    if isSyncingMutedContent {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                FlowLayout(spacing: 8) {
                    Button {
                        exportLocalMutedContent()
                    } label: {
                        Label(L10n.exportMutedContent, systemImage: "square.and.arrow.up")
                    }
                    .disabled(isSyncingMutedContent || (store.mutedTagList.isEmpty && store.mutedUserList.isEmpty && store.mutedArtworkList.isEmpty))

                    Button {
                        isMutedContentImportConfirmationPresented = true
                    } label: {
                        Label(L10n.importMutedContent, systemImage: "square.and.arrow.down")
                    }
                    .disabled(isSyncingMutedContent)
                }

                if let mutedContentSyncMessage {
                    Text(mutedContentSyncMessage)
                        .font(.caption)
                        .foregroundStyle(mutedContentSyncMessageIsError ? .red : .secondary)
                        .textSelection(.enabled)
                }

                LabeledContent(L10n.mutedContent) {
                    Text(String(format: L10n.mutedContentCountFormat, mutedContentCount))
                        .foregroundStyle(.secondary)
                }

                Button {
                    store.select(.mutedContent)
                } label: {
                    Label(L10n.openMutedContentManager, systemImage: "eye.slash")
                }

                Divider()

                Toggle(L10n.privacyMode, isOn: privacyModeBinding)
                Text(L10n.privacyModeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L10n.protectSensitiveContent, isOn: screenCaptureProtectionBinding)
                Text(L10n.screenCaptureProtectionHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.session != nil {
                    Toggle(L10n.showAccountIdentity, isOn: accountIdentityBinding)
                    Text(L10n.accountIdentityPrivacyHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var downloadsSettingsSection: some View {
        if settingsMatches(downloadsSettingsTerms) {
            Section(L10n.downloads) {
                LabeledContent(L10n.downloadFolder) {
                    Text(store.downloads.downloadDirectoryPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                FlowLayout(spacing: 8) {
                    Button {
                        if store.downloads.chooseDownloadDirectory() {
                            showSettingsActionMessage(L10n.downloadFolderChanged)
                        }
                    } label: {
                        Label(L10n.chooseFolder, systemImage: "folder.badge.gearshape")
                    }

                    Button {
                        showSettingsActionMessage(
                            store.downloads.openDownloadDirectory()
                                ? L10n.openedDownloadFolder
                                : L10n.unableToOpenDownloadFolder
                        )
                    } label: {
                        Label(L10n.openFolder, systemImage: "folder")
                    }
                }

                Stepper(
                    value: maxConcurrentDownloadsBinding,
                    in: 1...4,
                    step: 1
                ) {
                    LabeledContent(L10n.concurrentDownloads) {
                        Text(store.downloads.maxConcurrentDownloads.formatted())
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }

                Text(L10n.concurrentDownloadsHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle(L10n.autoBookmarkDownloadedArtworks, isOn: autoBookmarkDownloadsBinding)
                Text(L10n.autoBookmarkDownloadedArtworksHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

                TextField(L10n.downloadNamingTemplate, text: downloadNamingTemplateBinding)
                    .textFieldStyle(.roundedBorder)

                Text(L10n.downloadNamingTemplateHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledContent(L10n.templatePreview) {
                    Text(store.downloads.downloadNamingTemplatePreview)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                Button {
                    showSettingsActionMessage(
                        store.downloads.resetDownloadNamingTemplate()
                            ? L10n.downloadTemplateReset
                            : L10n.downloadTemplateAlreadyDefault
                    )
                } label: {
                    Label(L10n.resetTemplate, systemImage: "arrow.counterclockwise")
                }
            }
        }
    }

    @ViewBuilder
    private var accountSettingsSection: some View {
        if settingsMatches(accountSettingsTerms) {
            if let session = store.session {
                Section(L10n.account) {
                    LabeledContent(
                        L10n.profile,
                        value: store.showAccountIdentity ? "\(session.user.name) @\(session.user.account)" : L10n.hidden
                    )

                    if store.storedAccounts.isEmpty == false {
                        ForEach(store.storedAccounts) { account in
                            StoredAccountRow(
                                account: account,
                                isCurrent: account.id == session.user.id,
                                showIdentity: store.showAccountIdentity,
                                switchAccount: {
                                    Task {
                                        await store.switchAccount(userID: account.id)
                                        showSettingsActionMessage(String(format: L10n.switchedAccountFormat, account.name))
                                    }
                                },
                                removeAccount: {
                                    accountRemovalCandidate = account
                                }
                            )
                        }
                    }

                    Button {
                        isAccountLoginPresented = true
                    } label: {
                        Label(L10n.addAccount, systemImage: "person.crop.circle.badge.plus")
                    }

                    Button(role: .destructive) {
                        isLogoutConfirmationPresented = true
                    } label: {
                        Label(L10n.logout, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } else {
                Section(L10n.account) {
                    Button {
                        isAccountLoginPresented = true
                    } label: {
                        Label(L10n.addAccount, systemImage: "person.crop.circle.badge.plus")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var advancedQASettingsSection: some View {
        if settingsMatches(advancedQASettingsTerms) {
            RuntimeReadinessView(store: store)
        }
    }

    @ViewBuilder
    private var settingsNoResultsSection: some View {
        if hasVisibleSettingsSections == false {
            Section {
                ContentUnavailableView(
                    L10n.noMatchingSettings,
                    systemImage: "line.3.horizontal.decrease.circle",
                    description: Text(L10n.noMatchingSettingsHint)
                )
            }
        }
    }

    private var hasVisibleSettingsSections: Bool {
        settingsMatches(generalSettingsTerms)
            || settingsMatches(readingSettingsTerms)
            || settingsMatches(discoverySettingsTerms)
            || settingsMatches(copyTemplateSettingsTerms)
            || settingsMatches(safetySettingsTerms)
            || settingsMatches(downloadsSettingsTerms)
            || settingsMatches(accountSettingsTerms)
            || settingsMatches(advancedQASettingsTerms)
    }

    private var settingsSearchQuery: String {
        settingsSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func settingsMatches(_ terms: [String]) -> Bool {
        guard settingsSearchQuery.isEmpty == false else { return true }
        return terms.contains { term in
            term.localizedCaseInsensitiveContains(settingsSearchQuery)
        }
    }

    private var generalSettingsTerms: [String] {
        [
            L10n.settingsGeneral,
            L10n.language,
            L10n.appearance,
            L10n.useOriginalImages,
            L10n.showTranslatedTags,
            L10n.layout,
            L10n.galleryLayout
        ]
    }

    private var readingSettingsTerms: [String] {
        [
            L10n.readingWindow,
            L10n.defaultArtworkReadingMode,
            L10n.defaultMangaReadingMode,
            L10n.restoreLastReadPage,
            L10n.trackpad,
            L10n.enableTrackpadGestures,
            L10n.twoFingerSwipeBehavior
        ]
    }

    private var discoverySettingsTerms: [String] {
        [
            L10n.settingsDiscovery,
            L10n.bookmarks,
            L10n.defaultBookmarkVisibility,
            L10n.autoTagBookmarksWithArtworkTags,
            L10n.followCreatorAfterBookmark,
            L10n.autoDownloadBookmarkedArtworks,
            L10n.followingCreators,
            L10n.pinnedCreators,
            L10n.defaultFollowVisibility
        ]
    }

    private var safetySettingsTerms: [String] {
        [
            L10n.settingsSafety,
            L10n.contentFilters,
            L10n.showContentBadges,
            L10n.hideMutedContent,
            L10n.hideAIArtworks,
            L10n.hideR18Artworks,
            L10n.hideR18GArtworks,
            L10n.maskSensitivePreviews,
            L10n.pixivRestrictedMode,
            L10n.mutedContent,
            L10n.syncFromPixiv,
            L10n.uploadToPixiv,
            L10n.privacy,
            L10n.privacyMode,
            L10n.protectSensitiveContent,
            L10n.showAccountIdentity
        ]
    }

    private var copyTemplateSettingsTerms: [String] {
        [
            L10n.sharing,
            L10n.artworkCopyTemplate,
            L10n.creatorCopyTemplate,
            L10n.copyTemplateHint,
            L10n.templatePreview
        ]
    }

    private var downloadsSettingsTerms: [String] {
        [
            L10n.downloads,
            L10n.downloadFolder,
            L10n.concurrentDownloads,
            L10n.autoBookmarkDownloadedArtworks,
            L10n.downloadNamingTemplate,
            L10n.templatePreview
        ]
    }

    private var accountSettingsTerms: [String] {
        [
            L10n.account,
            L10n.profile,
            L10n.addAccount,
            L10n.switchAccount,
            L10n.removeAccount,
            L10n.logout
        ]
    }

    private var advancedQASettingsTerms: [String] {
        [
            L10n.settingsAdvancedQA,
            L10n.runtimeReadiness,
            L10n.qaSettingsOrganization,
            L10n.runSearchDiagnostics,
            L10n.qaAccountHealth
        ]
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding {
            store.appLanguage
        } set: { value in
            store.setAppLanguage(value)
        }
    }

    private var originalBinding: Binding<Bool> {
        Binding {
            store.useOriginalImagesInDetail
        } set: { value in
            store.setUseOriginalImagesInDetail(value)
        }
    }

    private var translatedTagsBinding: Binding<Bool> {
        Binding {
            store.showTranslatedTags
        } set: { value in
            store.setShowTranslatedTags(value)
        }
    }

    private var showContentBadgesBinding: Binding<Bool> {
        Binding {
            store.showContentBadges
        } set: { value in
            store.setShowContentBadges(value)
        }
    }

    private var hideAIBinding: Binding<Bool> {
        Binding {
            store.hideAIArtworks
        } set: { value in
            store.setHideAIArtworks(value)
        }
    }

    private var hideMutedBinding: Binding<Bool> {
        Binding {
            store.hideMutedContent
        } set: { value in
            store.setHideMutedContent(value)
        }
    }

    private var hideR18Binding: Binding<Bool> {
        Binding {
            store.hideR18Artworks
        } set: { value in
            store.setHideR18Artworks(value)
        }
    }

    private var hideR18GBinding: Binding<Bool> {
        Binding {
            store.hideR18GArtworks
        } set: { value in
            store.setHideR18GArtworks(value)
        }
    }

    private var maskSensitivePreviewsBinding: Binding<Bool> {
        Binding {
            store.maskSensitivePreviews
        } set: { value in
            store.setMaskSensitivePreviews(value)
        }
    }

    private var restrictedModeBinding: Binding<Bool> {
        Binding {
            store.restrictedModeEnabled ?? false
        } set: { value in
            Task { await updateRestrictedMode(value) }
        }
    }

    private var defaultBookmarkRestrictBinding: Binding<BookmarkRestrict> {
        Binding {
            store.defaultBookmarkRestrict
        } set: { value in
            store.setDefaultBookmarkRestrict(value)
        }
    }

    private var defaultFollowRestrictBinding: Binding<BookmarkRestrict> {
        Binding {
            store.defaultFollowRestrict
        } set: { value in
            store.setDefaultFollowRestrict(value)
        }
    }

    private var followCreatorAfterBookmarkBinding: Binding<Bool> {
        Binding {
            store.followCreatorAfterBookmark
        } set: { value in
            store.setFollowCreatorAfterBookmark(value)
        }
    }

    private var autoTagBookmarksBinding: Binding<Bool> {
        Binding {
            store.autoTagBookmarksWithArtworkTags
        } set: { value in
            store.setAutoTagBookmarksWithArtworkTags(value)
        }
    }

    private var autoDownloadBookmarksBinding: Binding<Bool> {
        Binding {
            store.autoDownloadBookmarkedArtworks
        } set: { value in
            store.setAutoDownloadBookmarkedArtworks(value)
        }
    }

    private var autoBookmarkDownloadsBinding: Binding<Bool> {
        Binding {
            store.autoBookmarkDownloadedArtworks
        } set: { value in
            store.setAutoBookmarkDownloadedArtworks(value)
        }
    }

    private var galleryLayoutBinding: Binding<GalleryLayoutMode> {
        Binding {
            store.galleryLayoutMode
        } set: { value in
            store.setGalleryLayoutMode(value)
        }
    }

    private var downloadNamingTemplateBinding: Binding<String> {
        Binding {
            store.downloads.downloadNamingTemplate
        } set: { value in
            store.downloads.setDownloadNamingTemplate(value)
        }
    }

    private var maxConcurrentDownloadsBinding: Binding<Int> {
        Binding {
            store.downloads.maxConcurrentDownloads
        } set: { value in
            store.downloads.setMaxConcurrentDownloads(value)
        }
    }

    private var trackpadGesturesBinding: Binding<Bool> {
        Binding {
            store.trackpadGesturesEnabled
        } set: { value in
            store.setTrackpadGesturesEnabled(value)
        }
    }

    private var horizontalSwipeBehaviorBinding: Binding<TrackpadHorizontalSwipeBehavior> {
        Binding {
            store.horizontalSwipeBehavior
        } set: { value in
            store.setHorizontalSwipeBehavior(value)
        }
    }

    private var defaultArtworkReadingModeBinding: Binding<ArtworkReadingMode> {
        Binding {
            store.defaultArtworkReadingMode
        } set: { value in
            store.setDefaultArtworkReadingMode(value)
        }
    }

    private var defaultMangaReadingModeBinding: Binding<ArtworkReadingMode> {
        Binding {
            store.defaultMangaReadingMode
        } set: { value in
            store.setDefaultMangaReadingMode(value)
        }
    }

    private var restoreReaderProgressBinding: Binding<Bool> {
        Binding {
            store.restoreArtworkReaderProgress
        } set: { value in
            store.setRestoreArtworkReaderProgress(value)
        }
    }

    private var accountIdentityBinding: Binding<Bool> {
        Binding {
            store.showAccountIdentity
        } set: { value in
            store.setShowAccountIdentity(value)
        }
    }

    private var screenCaptureProtectionBinding: Binding<Bool> {
        Binding {
            store.screenCaptureProtectionEnabled
        } set: { value in
            store.setScreenCaptureProtectionEnabled(value)
        }
    }

    private var privacyModeBinding: Binding<Bool> {
        Binding {
            store.privacyModeEnabled
        } set: { value in
            store.setPrivacyModeEnabled(value)
        }
    }

    private var accountRemovalBinding: Binding<Bool> {
        Binding {
            accountRemovalCandidate != nil
        } set: { value in
            if value == false {
                accountRemovalCandidate = nil
            }
        }
    }

    private var mutedContentCount: Int {
        store.mutedTagList.count + store.mutedUserList.count + store.mutedArtworkList.count
    }

    private func syncMutedContentFromPixiv() async {
        isSyncingMutedContent = true
        mutedContentSyncMessage = nil
        mutedContentSyncMessageIsError = false
        defer { isSyncingMutedContent = false }

        do {
            let snapshot = store.mutedContentArchiveSnapshot()
            try await store.importAccountMutedContent()
            store.undoAction = AppUndoAction(kind: .restoreMutedContentSnapshot(snapshot))
            mutedContentSyncMessage = L10n.synced
            mutedContentSyncMessageIsError = false
        } catch {
            mutedContentSyncMessage = error.localizedDescription
            mutedContentSyncMessageIsError = true
        }
    }

    private func uploadMutedContentToPixiv() async {
        isSyncingMutedContent = true
        mutedContentSyncMessage = nil
        mutedContentSyncMessageIsError = false
        defer { isSyncingMutedContent = false }

        do {
            try await store.uploadLocalMutedContentToAccount()
            mutedContentSyncMessage = L10n.uploaded
            mutedContentSyncMessageIsError = false
        } catch {
            mutedContentSyncMessage = error.localizedDescription
            mutedContentSyncMessageIsError = true
        }
    }

    private func exportLocalMutedContent() {
        mutedContentSyncMessage = nil
        mutedContentSyncMessageIsError = false
        do {
            if try store.exportMutedContentToFile() {
                mutedContentSyncMessage = L10n.exported
                mutedContentSyncMessageIsError = false
            }
        } catch {
            mutedContentSyncMessage = error.localizedDescription
            mutedContentSyncMessageIsError = true
        }
    }

    private func importLocalMutedContent() {
        mutedContentSyncMessage = nil
        mutedContentSyncMessageIsError = false
        do {
            let snapshot = store.mutedContentArchiveSnapshot()
            if try store.importMutedContentFromFile() {
                store.undoAction = AppUndoAction(kind: .restoreMutedContentSnapshot(snapshot))
                mutedContentSyncMessage = L10n.imported
                mutedContentSyncMessageIsError = false
            }
        } catch {
            mutedContentSyncMessage = error.localizedDescription
            mutedContentSyncMessageIsError = true
        }
    }

    private func updateRestrictedMode(_ value: Bool) async {
        isUpdatingRestrictedMode = true
        restrictedModeMessage = nil
        defer { isUpdatingRestrictedMode = false }

        do {
            try await store.setRestrictedModeEnabled(value)
        } catch {
            restrictedModeMessage = error.localizedDescription
        }
    }

    private func showSettingsActionMessage(_ message: String) {
        settingsActionMessage = message
    }

    private func dismissSettingsActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2.5))
        if settingsActionMessage == message {
            settingsActionMessage = nil
        }
    }
}
