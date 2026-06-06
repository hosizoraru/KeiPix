import SwiftUI

struct FeedFilterClearChip: View {
    let title: String
    let clearLabel: String
    let systemImage: String
    var maximumWidth: CGFloat?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Image(systemName: "xmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: maximumWidth ?? defaultMaximumWidth, alignment: .leading)
        .keiInteractiveGlass(17)
        .help(clearLabel)
        .accessibilityLabel("\(title), \(clearLabel)")
    }

    private var defaultMaximumWidth: CGFloat {
        #if os(iOS)
        190
        #else
        240
        #endif
    }
}
