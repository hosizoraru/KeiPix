import SwiftUI

struct PixivIDOpenSheet: View {
    @Bindable var store: KeiPixStore
    let showStatus: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var target: PixivIDOpenTarget = .artwork
    @State private var rawID = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Picker(L10n.openPixivIDTarget, selection: $target) {
                ForEach(PixivIDOpenTarget.allCases) { option in
                    Label(option.title, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)

            TextField(target.placeholder, text: $rawID)
                .textFieldStyle(.roundedBorder)
                .font(.title3.monospacedDigit())
                .onSubmit(openID)

            HStack {
                Button(L10n.cancel) {
                    dismiss()
                }

                Spacer()

                Button {
                    openID()
                } label: {
                    Label(L10n.open, systemImage: target.systemImage)
                }
                .buttonStyle(.glassProminent)
                .disabled(normalizedID == nil)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L10n.openPixivID, systemImage: "number")
                .font(.title2.weight(.semibold))
            Text(L10n.openPixivIDHint)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var normalizedID: Int? {
        PixivIDInput.normalizedID(from: rawID)
    }

    private func openID() {
        guard let id = normalizedID else { return }

        Task {
            let message = await store.openPixivID(id, target: target)
            showStatus(message)
            dismiss()
        }
    }
}
