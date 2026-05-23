import SwiftUI

struct SettingsView: View {
    @Bindable var store: KeiPixStore
    @State private var isSyncingMutedContent = false
    @State private var mutedContentSyncMessage: String?

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
            }

            Section(L10n.contentFilters) {
                Toggle(L10n.showContentBadges, isOn: showContentBadgesBinding)
                Toggle(L10n.hideMutedContent, isOn: hideMutedBinding)
                Toggle(L10n.hideAIArtworks, isOn: hideAIBinding)
                Toggle(L10n.hideR18Artworks, isOn: hideR18Binding)
                Toggle(L10n.hideR18GArtworks, isOn: hideR18GBinding)
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

            if let session = store.session {
                Section(L10n.privacy) {
                    Toggle(L10n.showAccountIdentity, isOn: accountIdentityBinding)
                    Text(L10n.accountIdentityPrivacyHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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
