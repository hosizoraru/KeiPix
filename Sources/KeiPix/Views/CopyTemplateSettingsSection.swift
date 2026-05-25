import SwiftUI

struct CopyTemplateSettingsSection: View {
    @Bindable var store: KeiPixStore
    var showMessage: (String) -> Void

    var body: some View {
        Section(L10n.sharing) {
            Text(L10n.copyTemplateHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.artworkCopyTemplate)
                    .font(.subheadline.weight(.medium))
                TextEditor(text: artworkCopyTemplateBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            LabeledContent(L10n.templatePreview) {
                Text(store.artworkCopyTemplatePreview)
                    .lineLimit(6)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
            }

            Button {
                showMessage(
                    store.resetArtworkCopyTemplate()
                        ? L10n.copyTemplateReset
                        : L10n.copyTemplateAlreadyDefault
                )
            } label: {
                Label(L10n.resetArtworkCopyTemplate, systemImage: "arrow.counterclockwise")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.creatorCopyTemplate)
                    .font(.subheadline.weight(.medium))
                TextField(L10n.creatorCopyTemplate, text: creatorCopyTemplateBinding)
                    .textFieldStyle(.roundedBorder)
            }

            LabeledContent(L10n.templatePreview) {
                Text(store.creatorCopyTemplatePreview)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            Button {
                showMessage(
                    store.resetCreatorCopyTemplate()
                        ? L10n.copyTemplateReset
                        : L10n.copyTemplateAlreadyDefault
                )
            } label: {
                Label(L10n.resetCreatorCopyTemplate, systemImage: "arrow.counterclockwise")
            }
        }
    }

    private var artworkCopyTemplateBinding: Binding<String> {
        Binding {
            store.artworkCopyTemplate
        } set: { value in
            store.setArtworkCopyTemplate(value)
        }
    }

    private var creatorCopyTemplateBinding: Binding<String> {
        Binding {
            store.creatorCopyTemplate
        } set: { value in
            store.setCreatorCopyTemplate(value)
        }
    }
}
