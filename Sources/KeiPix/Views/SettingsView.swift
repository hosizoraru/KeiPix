import SwiftUI

struct SettingsView: View {
    @Bindable var store: KeiPixStore
    @State private var coordinator = SettingsCoordinator()

    var body: some View {
        settingsRoot
            .overlay(alignment: .bottom) {
                VStack(spacing: 8) {
                    if let actionMessage = coordinator.actionMessage {
                        FloatingStatusBanner(maxWidth: 520) {
                            Text(actionMessage)
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
            .animation(.snappy(duration: 0.18), value: coordinator.actionMessage)
            .animation(.snappy(duration: 0.18), value: store.undoAction?.id)
            .task(id: coordinator.actionMessage) {
                await dismissActionMessageIfNeeded(coordinator.actionMessage)
            }
            .task {
                applyVisualQAInitialSelection()
                if store.session != nil, store.restrictedModeEnabled == nil {
                    await store.refreshRestrictedModeSetting()
                }
                if store.session != nil, store.aiShowEnabled == nil {
                    await store.refreshAIShowSetting()
                }
            }
            .sheet(isPresented: $coordinator.isAccountLoginPresented) {
                LoginSheetView(store: store)
                    .frame(width: 900, height: 680)
                    .os26SheetChrome(.immersive)
            }
            .sheet(isPresented: $coordinator.isTokenLoginPresented) {
                TokenLoginSheetView(store: store)
                    .frame(width: 460, height: 300)
                    .os26SheetChrome(.form)
            }
            .confirmationDialog(
                L10n.logout,
                isPresented: $coordinator.isLogoutConfirmationPresented,
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
                coordinator.accountRemovalCandidate
                    .map { String(format: L10n.removeAccountConfirmationFormat, $0.name) }
                    ?? L10n.removeAccount,
                isPresented: coordinator.accountRemovalBinding,
                titleVisibility: .visible,
                presenting: coordinator.accountRemovalCandidate
            ) { account in
                Button(L10n.removeAccount, role: .destructive) {
                    Task {
                        await store.removeStoredAccount(userID: account.id)
                        coordinator.setActionMessage(
                            String(format: L10n.removedAccountFormat, account.name)
                        )
                    }
                }
                Button(L10n.cancel, role: .cancel) {
                    coordinator.accountRemovalCandidate = nil
                }
            } message: { account in
                Text(String(format: L10n.removeAccountConfirmationFormat, account.name))
            }
            .confirmationDialog(
                L10n.copyRefreshToken,
                isPresented: $coordinator.isRefreshTokenCopyConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(L10n.copyRefreshToken) {
                    copyCurrentRefreshToken()
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.copyRefreshTokenConfirmationMessage)
            }
            .confirmationDialog(
                L10n.syncMutedContentConfirmation,
                isPresented: $coordinator.isMutedContentSyncConfirmationPresented,
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
                isPresented: $coordinator.isMutedContentUploadConfirmationPresented,
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
                isPresented: $coordinator.isMutedContentImportConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button(L10n.importMutedContent) {
                    importLocalMutedContent()
                }
                Button(L10n.cancel, role: .cancel) {}
            } message: {
                Text(L10n.importMutedContentConfirmationMessage)
            }
    }

    @ViewBuilder
    private var settingsRoot: some View {
        #if os(macOS)
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationSplitViewStyle(.balanced)
        .frame(
            minWidth: 820,
            idealWidth: 1000,
            maxWidth: .infinity,
            minHeight: 580,
            idealHeight: 720,
            maxHeight: .infinity
        )
        #else
        compactSettingsWorkspace
        #endif
    }

    private var compactSettingsWorkspace: some View {
        VStack(spacing: 0) {
            compactHeader

            detail
                .id(coordinator.selection)
                .environment(\.os26SettingsPageShowsHeader, false)
                .environment(\.os26SettingsPageUsesAdaptiveGrid, true)
                .transition(.opacity.combined(with: .move(edge: .trailing)))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.clear)
    }

    private var compactHeader: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        compactTitleBlock
                        Spacer(minLength: 16)
                        compactSearchField(maxWidth: 340)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        compactTitleBlock
                        compactSearchField(maxWidth: .infinity)
                    }
                }

                categoryRail
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var compactTitleBlock: some View {
        HStack(spacing: 10) {
            Image(systemName: coordinator.selection.systemImage)
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .frame(width: 38, height: 38)
                .keiGlass(14)

            VStack(alignment: .leading, spacing: 2) {
                Text(L10n.settings)
                    .font(.title2.weight(.bold))
                Text(coordinator.selection.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func compactSearchField(maxWidth: CGFloat) -> some View {
        OS26LibrarySearchField(
            text: $coordinator.searchText,
            placeholder: L10n.searchSettings,
            minWidth: 190,
            idealWidth: 260,
            maxWidth: maxWidth
        )
    }

    private var categoryRail: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(coordinator.visibleCategories) { category in
                    Button {
                        withAnimation(.snappy(duration: 0.2)) {
                            coordinator.selection = category
                        }
                    } label: {
                        Label(category.title, systemImage: category.systemImage)
                            .lineLimit(1)
                    }
                    .os26GlassButton(prominent: category == coordinator.selection)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var sidebar: some View {
        let categories = coordinator.visibleCategories
        #if os(macOS)
        List(selection: sidebarSelection) {
            ForEach(categories) { category in
                Label(category.title, systemImage: category.systemImage)
                    .tag(category)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(L10n.settings)
        .searchable(
            text: $coordinator.searchText,
            placement: .sidebar,
            prompt: Text(L10n.searchSettings)
        )
        .frame(minWidth: 220, idealWidth: 240)
        #else
        List {
            ForEach(categories) { category in
                Button {
                    coordinator.selection = category
                } label: {
                    Label(category.title, systemImage: category.systemImage)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(L10n.settings)
        .searchable(
            text: $coordinator.searchText,
            prompt: Text(L10n.searchSettings)
        )
        #endif
    }

    @ViewBuilder
    private var detail: some View {
        switch coordinator.selection {
        case .general:
            GeneralSettingsPage(store: store)
        case .reading:
            ReadingSettingsPage(store: store)
        case .discovery:
            DiscoverySettingsPage(store: store)
        case .sharing:
            SharingSettingsPage(store: store, coordinator: coordinator)
        case .safety:
            SafetySettingsPage(
                store: store,
                coordinator: coordinator,
                updateRestrictedMode: { value in await updateRestrictedMode(value) },
                updateAIShow: { value in await updateAIShow(value) },
                syncFromPixiv: { await syncMutedContentFromPixiv() },
                uploadToPixiv: { await uploadMutedContentToPixiv() },
                importLocalFile: { importLocalMutedContent() },
                exportLocalFile: { exportLocalMutedContent() }
            )
        case .privacy:
            PrivacySettingsPage(store: store, coordinator: coordinator)
        case .downloads:
            DownloadsSettingsPage(store: store, coordinator: coordinator)
        case .storage:
            StorageSettingsPage(store: store, coordinator: coordinator)
        case .account:
            AccountSettingsPage(store: store, coordinator: coordinator)
        case .keyboard:
            KeyboardSettingsPage()
        case .about:
            AboutView(presentation: .settings)
        case .advancedQA:
            AdvancedQASettingsPage(store: store, coordinator: coordinator)
        }
    }

    /// Two-way sidebar selection. Always coerces to a non-nil value so the
    /// detail pane stays populated, and falls back to the first visible
    /// category when the active selection is filtered out.
    private var sidebarSelection: Binding<SettingsCategory> {
        Binding {
            let visible = coordinator.visibleCategories
            if visible.contains(coordinator.selection) {
                return coordinator.selection
            }
            return visible.first ?? .general
        } set: { newValue in
            coordinator.selection = newValue
        }
    }

    private func applyVisualQAInitialSelection() {
        if VisualQALaunchArgument.contains(.runtimeReadiness) {
            coordinator.selection = .advancedQA
        } else if VisualQALaunchArgument.contains(.sharingTemplates) {
            coordinator.selection = .sharing
        }
    }

    private func dismissActionMessageIfNeeded(_ message: String?) async {
        guard let message else { return }
        try? await Task.sleep(for: .seconds(2.5))
        coordinator.clearActionMessage(matching: message)
    }

    private func syncMutedContentFromPixiv() async {
        coordinator.isSyncingMutedContent = true
        coordinator.mutedContentMessage = nil
        coordinator.mutedContentMessageIsError = false
        defer { coordinator.isSyncingMutedContent = false }

        do {
            let snapshot = store.mutedContentArchiveSnapshot()
            try await store.importAccountMutedContent()
            store.undoAction = AppUndoAction(kind: .restoreMutedContentSnapshot(snapshot))
            coordinator.mutedContentMessage = L10n.synced
            coordinator.mutedContentMessageIsError = false
        } catch {
            coordinator.mutedContentMessage = error.localizedDescription
            coordinator.mutedContentMessageIsError = true
        }
    }

    private func uploadMutedContentToPixiv() async {
        coordinator.isSyncingMutedContent = true
        coordinator.mutedContentMessage = nil
        coordinator.mutedContentMessageIsError = false
        defer { coordinator.isSyncingMutedContent = false }

        do {
            try await store.uploadLocalMutedContentToAccount()
            coordinator.mutedContentMessage = L10n.uploaded
            coordinator.mutedContentMessageIsError = false
        } catch {
            coordinator.mutedContentMessage = error.localizedDescription
            coordinator.mutedContentMessageIsError = true
        }
    }

    private func exportLocalMutedContent() {
        coordinator.mutedContentMessage = nil
        coordinator.mutedContentMessageIsError = false
        do {
            if try store.exportMutedContentToFile() {
                coordinator.mutedContentMessage = L10n.exported
                coordinator.mutedContentMessageIsError = false
            }
        } catch {
            coordinator.mutedContentMessage = error.localizedDescription
            coordinator.mutedContentMessageIsError = true
        }
    }

    private func importLocalMutedContent() {
        coordinator.mutedContentMessage = nil
        coordinator.mutedContentMessageIsError = false
        do {
            let snapshot = store.mutedContentArchiveSnapshot()
            if try store.importMutedContentFromFile() {
                store.undoAction = AppUndoAction(kind: .restoreMutedContentSnapshot(snapshot))
                coordinator.mutedContentMessage = L10n.imported
                coordinator.mutedContentMessageIsError = false
            }
        } catch {
            coordinator.mutedContentMessage = error.localizedDescription
            coordinator.mutedContentMessageIsError = true
        }
    }

    private func copyCurrentRefreshToken() {
        guard let refreshToken = store.session?.refreshToken,
              refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            coordinator.setActionMessage(L10n.errorLoginRequired)
            return
        }
        PasteboardWriter.copy(refreshToken)
        coordinator.setActionMessage(L10n.copiedRefreshToken)
    }

    private func updateRestrictedMode(_ value: Bool) async {
        coordinator.isUpdatingRestrictedMode = true
        coordinator.restrictedModeMessage = nil
        defer { coordinator.isUpdatingRestrictedMode = false }

        do {
            try await store.setRestrictedModeEnabled(value)
        } catch {
            coordinator.restrictedModeMessage = error.localizedDescription
        }
    }

    private func updateAIShow(_ value: Bool) async {
        coordinator.isUpdatingAIShow = true
        coordinator.aiShowMessage = nil
        defer { coordinator.isUpdatingAIShow = false }

        do {
            try await store.setAIShowEnabled(value)
        } catch {
            coordinator.aiShowMessage = error.localizedDescription
        }
    }
}
