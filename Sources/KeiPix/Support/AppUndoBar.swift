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
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 560)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
    }
}
