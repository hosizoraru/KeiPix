import Foundation
import SwiftUI

/// Holds Settings-window UI state shared across the sidebar shell, the
/// per-category pages, and the floating banner overlay.
///
/// Keeps `SettingsView` lean and lets each detail page bind only the state it
/// actually needs. Persists the selected category in `UserDefaults` so the
/// window reopens on the user's last page.
@MainActor
@Observable
final class SettingsCoordinator {
    private static let lastCategoryKey = "KeiPix.Settings.LastCategory"

    var selection: SettingsCategory {
        didSet {
            UserDefaults.standard.set(selection.rawValue, forKey: Self.lastCategoryKey)
        }
    }

    var searchText: String = ""

    var actionMessage: String?

    var isSyncingMutedContent = false
    var mutedContentMessage: String?
    var mutedContentMessageIsError = false

    var isUpdatingRestrictedMode = false
    var restrictedModeMessage: String?

    var isLogoutConfirmationPresented = false
    var isAccountLoginPresented = false
    var isTokenLoginPresented = false
    var accountRemovalCandidate: PixivStoredAccount?
    var isMutedContentSyncConfirmationPresented = false
    var isMutedContentUploadConfirmationPresented = false
    var isMutedContentImportConfirmationPresented = false

    /// Long-lived state for the Advanced QA page. Lives on the coordinator so
    /// diagnostic results survive when the user switches between sidebar
    /// destinations and comes back. The page itself is torn down on every
    /// switch (NavigationSplitView rebuilds the detail when selection
    /// changes), but the coordinator outlives the window.
    let runtimeReadinessState = RuntimeReadinessState()

    init(initialSelection: SettingsCategory? = nil) {
        if let initialSelection {
            self.selection = initialSelection
        } else if let visualQASelection = SettingsCategory.visualQAOverride {
            // Apply visual-QA overrides synchronously so the correct page
            // appears on the very first frame instead of flashing the last
            // persisted destination.
            self.selection = visualQASelection
        } else if
            let raw = UserDefaults.standard.string(forKey: Self.lastCategoryKey),
            let restored = SettingsCategory(rawValue: raw)
        {
            self.selection = restored
        } else {
            self.selection = .general
        }
    }

    /// Categories matching the current sidebar search text. Always returns at
    /// least one entry so the user never sees an empty sidebar.
    var visibleCategories: [SettingsCategory] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return SettingsCategory.allCases
        }
        let matches = SettingsCategory.allCases.filter { $0.matches(trimmed) }
        return matches.isEmpty ? SettingsCategory.allCases : matches
    }

    func setActionMessage(_ message: String) {
        actionMessage = message
    }

    func clearActionMessage(matching message: String?) {
        guard let message else { return }
        if actionMessage == message {
            actionMessage = nil
        }
    }

    var accountRemovalBinding: Binding<Bool> {
        Binding {
            self.accountRemovalCandidate != nil
        } set: { newValue in
            if newValue == false {
                self.accountRemovalCandidate = nil
            }
        }
    }
}
