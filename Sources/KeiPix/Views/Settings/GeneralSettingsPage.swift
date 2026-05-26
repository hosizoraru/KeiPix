import SwiftUI

struct GeneralSettingsPage: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Form {
            Section {
                Picker(L10n.language, selection: store.settings_languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.title).tag(language)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L10n.appearance)
            }

            Section {
                Toggle(L10n.useOriginalImages, isOn: store.settings_useOriginalImagesBinding)
                Toggle(L10n.showTranslatedTags, isOn: store.settings_showTranslatedTagsBinding)
            }

            Section {
                Picker(L10n.galleryLayout, selection: store.settings_galleryLayoutBinding) {
                    ForEach(GalleryLayoutMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text(L10n.layout)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.settingsGeneral)
    }
}
