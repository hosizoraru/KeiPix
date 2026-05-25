import SwiftUI

struct TokenLoginSheetView: View {
    @Bindable var store: KeiPixStore
    @Environment(\.dismiss) private var dismiss
    @State private var refreshToken = ""
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "key")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 5) {
                    Text(L10n.importToken)
                        .font(.headline)
                    Text(L10n.importTokenHint)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            SecureField(L10n.refreshToken, text: $refreshToken)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    importToken()
                }

            if let errorMessage = store.errorMessage, isImporting == false {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack {
                Button(L10n.cancel) {
                    store.errorMessage = nil
                    store.isTokenLoginPresented = false
                    dismiss()
                }
                Spacer()
                Button {
                    importToken()
                } label: {
                    if isImporting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(L10n.importToken, systemImage: "key.fill")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedToken.isEmpty || isImporting)
            }
        }
        .padding(20)
    }

    private var trimmedToken: String {
        refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func importToken() {
        guard trimmedToken.isEmpty == false, isImporting == false else { return }
        isImporting = true
        store.errorMessage = nil
        Task {
            let success = await store.completeTokenLogin(refreshToken: trimmedToken)
            isImporting = false
            if success {
                dismiss()
            }
        }
    }
}
