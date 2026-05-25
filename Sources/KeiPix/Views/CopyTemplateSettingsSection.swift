import SwiftUI

struct CopyTemplateSettingsSection: View {
    @Bindable var store: KeiPixStore
    var showMessage: (String) -> Void

    var body: some View {
        Section(L10n.sharing) {
            Text(L10n.copyTemplateHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 18) {
                templateEditorContent
                    .frame(width: 380)
                Divider()
                templatePreviewContent
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var templateEditorContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.artworkCopyTemplate)
                    .font(.subheadline.weight(.medium))
                TextEditor(text: artworkCopyTemplateBinding)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.creatorCopyTemplate)
                    .font(.subheadline.weight(.medium))
                TextField(L10n.creatorCopyTemplate, text: creatorCopyTemplateBinding)
                    .textFieldStyle(.roundedBorder)
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

    private var templatePreviewContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.templatePreview)
                .font(.subheadline.weight(.medium))

            Text(store.artworkCopyTemplatePreview)
                .lineLimit(8)
                .truncationMode(.tail)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            Text(store.creatorCopyTemplatePreview)
                .lineLimit(3)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
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
