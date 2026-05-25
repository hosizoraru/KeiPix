import SwiftUI

struct MutableActionQAAuthorizationSheet: View {
    let runQA: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var confirmationText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Label(L10n.mutableActionQAAuthorization, systemImage: "hand.raised.circle")
                    .font(.title2.weight(.semibold))
                Text(L10n.mutableActionQAAuthorizationHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            TextField(L10n.mutableActionQAAuthorizationPrompt, text: $confirmationText)
                .textFieldStyle(.roundedBorder)
                .onSubmit(runIfAuthorized)

            HStack {
                Button(L10n.cancel) {
                    dismiss()
                }

                Spacer()

                Button(role: .destructive) {
                    runIfAuthorized()
                } label: {
                    Label(L10n.runMutableActionQA, systemImage: "checkmark.shield")
                }
                .buttonStyle(.glassProminent)
                .disabled(MutableActionQAAuthorization.isAuthorized(confirmationText) == false)
            }
        }
        .padding(24)
        .frame(width: 460)
    }

    private func runIfAuthorized() {
        guard MutableActionQAAuthorization.isAuthorized(confirmationText) else { return }
        runQA()
        dismiss()
    }
}
