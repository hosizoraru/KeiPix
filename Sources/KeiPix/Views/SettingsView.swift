import SwiftUI

struct SettingsView: View {
    @Bindable var store: KeiPixStore
    @State private var coordinator = SettingsCoordinator()

    var body: some View {
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
                .iPadFriendlySheet()
        }
        .sheet(isPresented: $coordinator.isTokenLoginPresented) {
            TokenLoginSheetView(store: store)
                .frame(width: 460, height: 300)
                .iPadFriendlySheet()
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
    private var sidebar: some View {
        let categories = coordinator.visibleCategories
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
