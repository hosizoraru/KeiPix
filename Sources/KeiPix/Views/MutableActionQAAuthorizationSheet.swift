import SwiftUI

struct MutableActionQAAuthorizationSheet: View {
    let runQA: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmationText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(L10n.mutableActionQAAuthorization, systemImage: "hand.raised.circle")
                        .font(.title2.weight(.semibold))
                    Text(L10n.mutableActionQAAuthorizationHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                SheetCloseButton(style: .plain)
            }

            OS26LibraryTextEntryField(
                text: $confirmationText,
                placeholder: L10n.mutableActionQAAuthorizationPrompt,
                minWidth: 260
            )
                .onSubmit(runIfAuthorized)

            HStack {
                Button(L10n.cancel) {
                    dismiss()
                }
                .os26GlassButton()
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(role: .destructive) {
                    runIfAuthorized()
                } label: {
                    Label(L10n.runMutableActionQA, systemImage: "checkmark.shield")
                }
                .os26GlassButton(prominent: true)
                .keyboardShortcut(.defaultAction)
                .disabled(MutableActionQAAuthorization.isAuthorized(confirmationText) == false)
            }
        }
        .padding(24)
        #if os(macOS)
        .frame(width: 460)
        #endif
    }

    private func runIfAuthorized() {
        guard MutableActionQAAuthorization.isAuthorized(confirmationText) else { return }
        runQA()
        dismiss()
    }
}
