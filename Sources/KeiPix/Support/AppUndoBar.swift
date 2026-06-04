import SwiftUI

struct AppUndoBar: View {
    let action: AppUndoAction
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(action.message)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer()

            Button(L10n.undo, action: undo)
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 560)
        .keiGlass(16)
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }
}
