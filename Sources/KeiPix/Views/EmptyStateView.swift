import SwiftUI

struct EmptyStateView: View {
    let title: String
    let subtitle: String
    let systemImage: String

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 46

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: iconSize, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.title3.weight(.semibold))
            Text(subtitle)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PixivSignedOutStateView: View {
    @Bindable var store: KeiPixStore

    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 42

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                GlassEffectContainer(spacing: 18) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 18) {
                            signedOutHero
                                .frame(width: 310)
                            signedOutActions
                                .frame(minWidth: 360, maxWidth: 470)
                        }

                        VStack(spacing: 16) {
                            signedOutHero
                            signedOutActions
                        }
                    }
                }
                .frame(maxWidth: 820)
                .frame(minHeight: max(0, proxy.size.height - 56))
                .padding(28)
                .frame(maxWidth: .infinity)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var signedOutHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 13) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: iconSize, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 68, height: 68)
                    .keiGlass(24)

                VStack(alignment: .leading, spacing: 3) {
                    Text("KeiPix")
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)

                    Text(L10n.pixivSection)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.signedOutTitle)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Text(L10n.signedOutSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            FlowLayout(spacing: 8) {
                signedOutStatusPill(title: L10n.pixivAPI, systemImage: "network")
                signedOutStatusPill(title: L10n.privacy, systemImage: "lock.shield")
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .keiGlass(30)
    }

    private var signedOutActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Button {
                    store.isLoginPresented = true
                } label: {
                    Label(L10n.loginTitle, systemImage: "person.crop.circle.badge.plus")
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                .labelStyle(.titleAndIcon)
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .help(L10n.loginHint)
                .accessibilityLabel(L10n.login)

                Text(L10n.loginHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .keiGlass(24)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    guestActionCard
                    tokenActionCard
                }

                VStack(spacing: 12) {
                    guestActionCard
                    tokenActionCard
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var guestActionCard: some View {
        Button {
            store.activateGuestMode()
        } label: {
            signedOutActionLabel(
                title: L10n.guestAccount,
                subtitle: L10n.guestAccountSubtitle,
                systemImage: "sparkles.rectangle.stack"
            )
        }
        .buttonStyle(.plain)
        .help(L10n.guestAccountSubtitle)
        .accessibilityLabel(L10n.guestAccount)
        .keiInteractiveGlass(20)
    }

    private var tokenActionCard: some View {
        Button {
            store.isTokenLoginPresented = true
        } label: {
            signedOutActionLabel(
                title: L10n.importToken,
                subtitle: L10n.importTokenHint,
                systemImage: "key"
            )
        }
        .buttonStyle(.plain)
        .help(L10n.importTokenHint)
        .accessibilityLabel(L10n.importToken)
        .keiInteractiveGlass(20)
    }

    private func signedOutStatusPill(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: Capsule(style: .continuous))
    }

    private func signedOutActionLabel(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .keiGlass(14)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
