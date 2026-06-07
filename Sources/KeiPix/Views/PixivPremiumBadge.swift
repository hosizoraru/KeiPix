import SwiftUI

struct PixivPremiumBadge: View {
    var compact = true

    var body: some View {
        Text(compact ? "P" : L10n.premium)
            .font(compact ? .caption2.weight(.black) : .caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 5 : 8)
            .padding(.vertical, compact ? 2 : 4)
            .background(
                LinearGradient(
                    colors: [Self.primaryColor, Self.secondaryColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .stroke(.white.opacity(0.45), lineWidth: 0.8)
            }
            .shadow(color: .orange.opacity(0.28), radius: 4, y: 1)
            .help(L10n.pixivPremiumRequired)
            .accessibilityLabel(L10n.pixivPremiumRequired)
    }

    private static let primaryColor = Color(red: 0.992, green: 0.620, blue: 0.086)
    private static let secondaryColor = Color(red: 1.0, green: 0.588, blue: 0.0)
}

struct PixivPremiumMenuLabel: View {
    let title: String
    var systemImage: String
    var isSelected = false

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: isSelected ? "checkmark" : systemImage)
            Spacer(minLength: 10)
            PixivPremiumBadge()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(L10n.pixivPremiumRequired)")
    }
}

struct PixivPremiumInlineLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Label(title, systemImage: systemImage)
            PixivPremiumBadge()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(L10n.pixivPremiumRequired)")
    }
}
