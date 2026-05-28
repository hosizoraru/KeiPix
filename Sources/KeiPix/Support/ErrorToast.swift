import SwiftUI

/// Non-blocking error toast with action buttons.
///
/// Replaces the blocking `.alert` for transient network errors.
/// Shows as a floating banner at the bottom of the view with
/// Retry, Copy, and Dismiss actions. Auto-dismisses after a timeout.
struct ErrorToast: View {
    let message: String
    let onRetry: () -> Void
    let onCopy: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.body)

            Text(message)
                .font(.callout)
                .lineLimit(3)
                .textSelection(.enabled)

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button(L10n.retry, action: onRetry)
                    .controlSize(.small)

                Button(L10n.copyError, action: onCopy)
                    .controlSize(.small)

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 560, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
