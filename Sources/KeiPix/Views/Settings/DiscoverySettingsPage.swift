import SwiftUI

struct DiscoverySettingsPage: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        OS26SettingsPage(
            title: L10n.settingsDiscovery,
            subtitle: L10n.autoDownloadBookmarkedArtworksHint,
            systemImage: SettingsCategory.discovery.systemImage
        ) {
            OS26SettingsSection(
                L10n.bookmarks,
                systemImage: "bookmark",
                footer: "\(L10n.autoTagBookmarksWithArtworkTagsHint)\n\(L10n.followCreatorAfterBookmarkHint)\n\(L10n.autoDownloadBookmarkedArtworksHint)"
            ) {
                Picker(L10n.defaultBookmarkVisibility, selection: store.settings_defaultBookmarkRestrictBinding) {
                    ForEach(BookmarkRestrict.allCases) { restrict in
                        Text(restrict.title).tag(restrict)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(L10n.autoTagBookmarksWithArtworkTags, isOn: store.settings_autoTagBookmarksBinding)
                Toggle(L10n.followCreatorAfterBookmark, isOn: store.settings_followCreatorAfterBookmarkBinding)
                Toggle(L10n.autoDownloadBookmarkedArtworks, isOn: store.settings_autoDownloadBookmarksBinding)
            }

            OS26SettingsSection(L10n.followingCreators, systemImage: "person.2") {
                Picker(L10n.defaultFollowVisibility, selection: store.settings_defaultFollowRestrictBinding) {
                    ForEach(BookmarkRestrict.allCases) { restrict in
                        Text(restrict.title).tag(restrict)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}
