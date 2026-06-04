import SwiftUI

struct SharingSettingsPage: View {
    @Bindable var store: KeiPixStore
    var coordinator: SettingsCoordinator

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L10n.copyTemplateHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section(L10n.artworkCopyTemplate) {
                TextEditor(text: artworkTemplateBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .keiInteractiveGlass(14)

                LabeledContent(L10n.templatePreview) {
                    Text(store.artworkCopyTemplatePreview)
                        .lineLimit(8)
                        .truncationMode(.tail)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    coordinator.setActionMessage(
                        store.resetArtworkCopyTemplate()
                            ? L10n.copyTemplateReset
                            : L10n.copyTemplateAlreadyDefault
                    )
                } label: {
                    Label(L10n.resetArtworkCopyTemplate, systemImage: "arrow.counterclockwise")
                }
                .os26GlassButton()
            }

            Section(L10n.creatorCopyTemplate) {
                OS26LibraryTextEntryField(text: creatorTemplateBinding, placeholder: L10n.creatorCopyTemplate)

                LabeledContent(L10n.templatePreview) {
                    Text(store.creatorCopyTemplatePreview)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    coordinator.setActionMessage(
                        store.resetCreatorCopyTemplate()
                            ? L10n.copyTemplateReset
                            : L10n.copyTemplateAlreadyDefault
                    )
                } label: {
                    Label(L10n.resetCreatorCopyTemplate, systemImage: "arrow.counterclockwise")
                }
                .os26GlassButton()
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.sharing)
    }

    private var artworkTemplateBinding: Binding<String> {
        Binding {
            store.artworkCopyTemplate
        } set: { value in
            store.setArtworkCopyTemplate(value)
        }
    }

    private var creatorTemplateBinding: Binding<String> {
        Binding {
            store.creatorCopyTemplate
        } set: { value in
            store.setCreatorCopyTemplate(value)
        }
    }
}
