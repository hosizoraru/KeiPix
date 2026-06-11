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
                L10n.defaultBookmarkVisibility,
                systemImage: "bookmark",
                footer: "\(L10n.autoTagBookmarksWithArtworkTagsHint)\n\(L10n.followCreatorAfterBookmarkHint)\n\(L10n.autoDownloadBookmarkedArtworksHint)"
            ) {
                bookmarkDefaultVisibilityRow(
                    L10n.illustrations,
                    systemImage: "photo",
                    selection: store.settings_defaultIllustrationBookmarkRestrictBinding
                )
                bookmarkDefaultVisibilityRow(
                    L10n.manga,
                    systemImage: "rectangle.stack",
                    selection: store.settings_defaultMangaBookmarkRestrictBinding
                )
                bookmarkDefaultVisibilityRow(
                    L10n.novels,
                    systemImage: "book",
                    selection: store.settings_defaultNovelBookmarkRestrictBinding
                )

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

    private func bookmarkDefaultVisibilityRow(
        _ title: String,
        systemImage: String,
        selection: Binding<BookmarkRestrict>
    ) -> some View {
        LabeledContent {
            Picker(title, selection: selection) {
                ForEach(BookmarkRestrict.allCases) { restrict in
                    Text(restrict.title).tag(restrict)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 220, alignment: .trailing)
        } label: {
            Label(title, systemImage: systemImage)
                .lineLimit(1)
        }
    }
}
