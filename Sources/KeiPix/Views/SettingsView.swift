import SwiftUI

struct SettingsView: View {
    @Bindable var store: KeiPixStore

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
                Toggle(L10n.compactCards, isOn: compactCardsBinding)
            }

            if let session = store.session {
                Section(L10n.account) {
                    LabeledContent(L10n.profile, value: "\(session.user.name) @\(session.user.account)")
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

    private var compactCardsBinding: Binding<Bool> {
        Binding {
            store.compactArtworkCards
        } set: { value in
            store.setCompactArtworkCards(value)
        }
    }
}
