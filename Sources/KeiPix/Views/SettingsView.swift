import SwiftUI

struct SettingsView: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Form {
            Section(L10n.appearance) {
                Toggle(L10n.useOriginalImages, isOn: originalBinding)
            }
        }
        .formStyle(.grouped)
        .padding(24)
        .frame(width: 460)
    }

    private var originalBinding: Binding<Bool> {
        Binding {
            store.useOriginalImagesInDetail
        } set: { value in
            store.setUseOriginalImagesInDetail(value)
        }
    }
}
