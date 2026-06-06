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
    var includesOuterPadding = true

    @State private var isVisible = false

    var body: some View {
        ViewThatFits(in: .horizontal) {
            horizontalLayout
                .fixedSize(horizontal: true, vertical: false)
            compactLayout
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 560, alignment: .leading)
        .keiGlass(16)
        .shadow(color: .black.opacity(0.16), radius: 18, y: 8)
        .padding(.horizontal, includesOuterPadding ? 18 : 0)
        .padding(.bottom, includesOuterPadding ? 14 : 0)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var horizontalLayout: some View {
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
                retryButton
                copyButton
                closeButton
            }
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.body)

                Text(message)
                    .font(.callout)
                    .lineLimit(3)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                closeButton
            }

            HStack(spacing: 8) {
                retryButton
                copyButton
            }
        }
    }

    private var retryButton: some View {
        Button(L10n.retry, action: onRetry)
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var copyButton: some View {
        Button(L10n.copyError, action: onCopy)
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)
            .controlSize(.small)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var closeButton: some View {
        Button {
            onDismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.caption.weight(.semibold))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(L10n.close)
    }
}
