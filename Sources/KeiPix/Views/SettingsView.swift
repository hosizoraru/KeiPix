import SwiftUI

struct SettingsView: View {
    @Bindable var store: KeiPixStore
    @State private var isSyncingMutedContent = false
    @State private var isUpdatingRestrictedMode = false
    @State private var mutedContentSyncMessage: String?
    @State private var restrictedModeMessage: String?

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

                HStack(spacing: 10) {
                    Button {
                        Task { await syncMutedContentFromPixiv() }
                    } label: {
                        Label(L10n.syncFromPixiv, systemImage: "arrow.down.circle")
                    }
                    .disabled(isSyncingMutedContent)

                    Button {
                        Task { await uploadMutedContentToPixiv() }
                    } label: {
                        Label(L10n.uploadToPixiv, systemImage: "arrow.up.circle")
                    }
                    .disabled(isSyncingMutedContent || (store.mutedTagList.isEmpty && store.mutedUserList.isEmpty))

                    if isSyncingMutedContent {
                        ProgressView()
                            .controlSize(.small)
                    }
                }

                if let mutedContentSyncMessage {
                    Text(mutedContentSyncMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                if store.mutedTagList.isEmpty,
                   store.mutedUserList.isEmpty,
                   store.mutedArtworkList.isEmpty {
                    Text(L10n.noMutedContent)
                        .foregroundStyle(.secondary)
                } else {
                    MutedContentList(store: store)

                    Button(role: .destructive) {
                        store.clearMutedContent()
                    } label: {
                        Label(L10n.clearMutedContent, systemImage: "trash")
                    }
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

                HStack(spacing: 10) {
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
                        Task { await store.logout() }
                    } label: {
                        Label(L10n.logout, systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 520)
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

    private var galleryLayoutBinding: Binding<GalleryLayoutMode> {
        Binding {
            store.galleryLayoutMode
        } set: { value in
            store.setGalleryLayoutMode(value)
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

    private func syncMutedContentFromPixiv() async {
        isSyncingMutedContent = true
        mutedContentSyncMessage = nil
        defer { isSyncingMutedContent = false }

        do {
            try await store.importAccountMutedContent()
            mutedContentSyncMessage = L10n.synced
        } catch {
            mutedContentSyncMessage = error.localizedDescription
        }
    }

    private func uploadMutedContentToPixiv() async {
        isSyncingMutedContent = true
        mutedContentSyncMessage = nil
        defer { isSyncingMutedContent = false }

        do {
            try await store.uploadLocalMutedContentToAccount()
            mutedContentSyncMessage = L10n.uploaded
        } catch {
            mutedContentSyncMessage = error.localizedDescription
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

private struct MutedContentList: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        if store.mutedTagList.isEmpty == false {
            mutedGroup(L10n.mutedTags, systemImage: "tag") {
                ForEach(store.mutedTagList, id: \.self) { tag in
                    mutedRow(title: "#\(tag)", systemImage: "tag") {
                        store.unmuteTag(tag)
                    }
                }
            }
        }

        if store.mutedUserList.isEmpty == false {
            mutedGroup(L10n.mutedCreators, systemImage: "person.slash") {
                ForEach(store.mutedUserList) { user in
                    mutedRow(title: user.name, systemImage: "person") {
                        store.unmuteUser(id: user.id)
                    }
                }
            }
        }

        if store.mutedArtworkList.isEmpty == false {
            mutedGroup(L10n.mutedArtworks, systemImage: "photo.badge.exclamationmark") {
                ForEach(store.mutedArtworkList) { artwork in
                    mutedRow(title: artwork.title, systemImage: "photo") {
                        store.unmuteArtwork(id: artwork.id)
                    }
                }
            }
        }
    }

    private func mutedGroup<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                content()
            }
            .padding(.top, 6)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    private func mutedRow(title: String, systemImage: String, remove: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
                .lineLimit(1)

            Spacer()

            Button(role: .destructive, action: remove) {
                Image(systemName: "xmark.circle")
            }
            .buttonStyle(.borderless)
            .help(L10n.reset)
        }
        .font(.callout)
    }
}
