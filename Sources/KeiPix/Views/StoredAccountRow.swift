import SwiftUI

struct StoredAccountRow: View {
    let account: PixivStoredAccount
    let isCurrent: Bool
    let showIdentity: Bool
    let switchAccount: () -> Void
    let removeAccount: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            RemoteImageView(url: account.profileImageURL)
                .frame(width: 30, height: 30)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(showIdentity ? account.name : L10n.hidden)
                    .font(.headline)
                    .lineLimit(1)

                Text(showIdentity ? "@\(account.account)" : L10n.accountIdentityHidden)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Label(L10n.currentAccount, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button(action: switchAccount) {
                    Label(L10n.switchAccount, systemImage: "arrow.triangle.2.circlepath")
                }
                .os26GlassButton()
                .controlSize(.small)
            }

            Button(role: .destructive, action: removeAccount) {
                Label(L10n.removeAccount, systemImage: "trash")
            }
            .os26GlassIconButton()
            .controlSize(.small)
            .help(L10n.removeAccount)
        }
        .help(showIdentity ? "\(account.name) @\(account.account)" : L10n.accountIdentityHidden)
    }
}
