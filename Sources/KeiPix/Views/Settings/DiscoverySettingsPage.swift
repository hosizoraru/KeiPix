import SwiftUI

struct DiscoverySettingsPage: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Form {
            Section {
                Picker(L10n.defaultBookmarkVisibility, selection: store.settings_defaultBookmarkRestrictBinding) {
                    ForEach(BookmarkRestrict.allCases) { restrict in
                        Text(restrict.title).tag(restrict)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(L10n.autoTagBookmarksWithArtworkTags, isOn: store.settings_autoTagBookmarksBinding)
                Toggle(L10n.followCreatorAfterBookmark, isOn: store.settings_followCreatorAfterBookmarkBinding)
                Toggle(L10n.autoDownloadBookmarkedArtworks, isOn: store.settings_autoDownloadBookmarksBinding)
            } header: {
                Text(L10n.bookmarks)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.autoTagBookmarksWithArtworkTagsHint)
                    Text(L10n.followCreatorAfterBookmarkHint)
                    Text(L10n.autoDownloadBookmarkedArtworksHint)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Picker(L10n.defaultFollowVisibility, selection: store.settings_defaultFollowRestrictBinding) {
                    ForEach(BookmarkRestrict.allCases) { restrict in
                        Text(restrict.title).tag(restrict)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L10n.followingCreators)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.settingsDiscovery)
    }
}
