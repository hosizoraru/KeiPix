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
                systemImage: "bookmark"
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

                OS26SettingsToggleRow(
                    title: L10n.autoTagBookmarksWithArtworkTags,
                    detail: L10n.autoTagBookmarksWithArtworkTagsHint,
                    systemImage: "tag",
                    isOn: store.settings_autoTagBookmarksBinding
                )
                OS26SettingsToggleRow(
                    title: L10n.followCreatorAfterBookmark,
                    detail: L10n.followCreatorAfterBookmarkHint,
                    systemImage: "person.crop.circle.badge.plus",
                    isOn: store.settings_followCreatorAfterBookmarkBinding
                )
                OS26SettingsToggleRow(
                    title: L10n.autoDownloadBookmarkedArtworks,
                    detail: L10n.autoDownloadBookmarkedArtworksHint,
                    systemImage: "arrow.down.circle",
                    isOn: store.settings_autoDownloadBookmarksBinding
                )
            }

            OS26SettingsSection(L10n.followingCreators, systemImage: "person.2") {
                OS26SettingsMenuPicker(
                    title: L10n.defaultFollowVisibility,
                    value: store.defaultFollowRestrict.title,
                    detail: L10n.defaultFollowVisibilityHint,
                    systemImage: restrictSystemImage(store.defaultFollowRestrict),
                    selection: store.settings_defaultFollowRestrictBinding,
                    options: BookmarkRestrict.allCases
                ) { restrict, isSelected in
                    Label(restrict.title, systemImage: isSelected ? "checkmark" : restrictSystemImage(restrict))
                }
            }
        }
    }

    private func bookmarkDefaultVisibilityRow(
        _ title: String,
        systemImage: String,
        selection: Binding<BookmarkRestrict>
    ) -> some View {
        OS26SettingsMenuPicker(
            title: title,
            value: selection.wrappedValue.title,
            detail: L10n.defaultBookmarkVisibilityHint,
            systemImage: systemImage,
            selection: selection,
            options: BookmarkRestrict.allCases
        ) { restrict, isSelected in
            Label(restrict.title, systemImage: isSelected ? "checkmark" : restrictSystemImage(restrict))
        }
    }

    private func restrictSystemImage(_ restrict: BookmarkRestrict) -> String {
        switch restrict {
        case .public:
            "globe"
        case .private:
            "lock"
        }
    }
}
