import SwiftUI

struct TokenLoginSheetView: View {
    @Bindable var store: KeiPixStore
    @Environment(\.dismiss) private var dismiss
    @State private var refreshToken = ""
    @State private var isImporting = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SheetHeaderRail(
                title: L10n.importToken,
                subtitle: L10n.importTokenHint,
                leading: {
                    SheetHeaderIcon(systemImage: "key", tint: .accentColor)
                },
                closeAction: closeSheet
            )

            VStack(alignment: .leading, spacing: 16) {
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
                        closeSheet()
                    }
                    .keyboardShortcut(.cancelAction)

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
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.capsule)
                    .keyboardShortcut(.defaultAction)
                    .disabled(trimmedToken.isEmpty || isImporting)
                }
            }
            .padding(20)
        }
    }

    private func closeSheet() {
        store.errorMessage = nil
        store.isTokenLoginPresented = false
        dismiss()
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
