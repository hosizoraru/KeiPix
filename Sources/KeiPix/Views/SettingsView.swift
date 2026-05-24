import SwiftUI

struct SettingsView: View {
    @Bindable var store: KeiPixStore
    @State private var isSyncingMutedContent = false
    @State private var isUpdatingRestrictedMode = false
    @State private var mutedContentSyncMessage: String?
    @State private var mutedContentSyncMessageIsError = false
    @State private var restrictedModeMessage: String?
    @State private var isLogoutConfirmationPresented = false
    @State private var isMutedContentUploadConfirmationPresented = false

    var body: some View {
        Form {
            Section(L10n.language) {
                Picker(L10n.language, selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(L10n.appearance) {
                Toggle(L10n.useOriginalImages, isOn: originalBinding)
                Toggle(L10n.showTranslatedTags, isOn: translatedTagsBinding)
            }

            Section(L10n.contentFilters) {
                Toggle(L10n.showContentBadges, isOn: showContentBadgesBinding)
                Toggle(L10n.hideMutedContent, isOn: hideMutedBinding)
                Toggle(L10n.hideAIArtworks, isOn: hideAIBinding)
                Toggle(L10n.hideR18Artworks, isOn: hideR18Binding)
                Toggle(L10n.hideR18GArtworks, isOn: hideR18GBinding)

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
            }

            Section(L10n.bookmarks) {
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
            }

            Section(L10n.followingCreators) {
                Picker(L10n.defaultFollowVisibility, selection: defaultFollowRestrictBinding) {
                    ForEach(BookmarkRestrict.allCases) { restrict in
                        Text(restrict.title).tag(restrict)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(L10n.mutedContent) {
                Text(L10n.muteSyncHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                FlowLayout(spacing: 8) {
                    Button {
                        Task { await syncMutedContentFromPixiv() }
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
                        importLocalMutedContent()
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
            }

            Section(L10n.layout) {
                Picker(L10n.galleryLayout, selection: galleryLayoutBinding) {
                    ForEach(GalleryLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(L10n.downloads) {
                LabeledContent(L10n.downloadFolder) {
                    Text(store.downloads.downloadDirectoryPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                }

                FlowLayout(spacing: 8) {
                    Button {
                        store.downloads.chooseDownloadDirectory()
                    } label: {
                        Label(L10n.chooseFolder, systemImage: "folder.badge.gearshape")
                    }

                    Button {
                        store.downloads.openDownloadDirectory()
                    } label: {
                        Label(L10n.openFolder, systemImage: "folder")
                    }
                }

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
                    store.downloads.resetDownloadNamingTemplate()
                } label: {
                    Label(L10n.resetTemplate, systemImage: "arrow.counterclockwise")
                }
            }

            Section(L10n.trackpad) {
                Toggle(L10n.enableTrackpadGestures, isOn: trackpadGesturesBinding)

                Picker(L10n.twoFingerSwipeBehavior, selection: horizontalSwipeBehaviorBinding) {
                    ForEach(TrackpadHorizontalSwipeBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .pickerStyle(.menu)
            }

            Section(L10n.privacy) {
                Toggle(L10n.privacyMode, isOn: privacyModeBinding)
                Text(L10n.privacyModeHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()

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

            if let session = store.session {
                Section(L10n.account) {
                    LabeledContent(
                        L10n.profile,
                        value: store.showAccountIdentity ? "\(session.user.name) @\(session.user.account)" : L10n.hidden
                    )

                    Button(role: .destructive) {
                        isLogoutConfirmationPresented = true
                    } label: {
                        Label(L10n.logout, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }

            RuntimeReadinessView(store: store)
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 520)
        .overlay(alignment: .bottom) {
            if let undoAction = store.undoAction {
                AppUndoBar(action: undoAction) {
                    Task { await store.performUndo(undoAction) }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
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
        .task {
            if store.session != nil, store.restrictedModeEnabled == nil {
                await store.refreshRestrictedModeSetting()
            }
        }
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
}
