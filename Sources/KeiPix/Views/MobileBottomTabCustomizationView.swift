#if os(iOS)
import SwiftUI

struct MobileBottomTabCustomizationView: View {
    @Binding var defaultRoutes: [MobileBottomTabKind: PixivRoute]
    @Binding var launchTarget: MobileBottomTabLaunchTarget
    @Binding var remembersLastRoute: Bool
    @Environment(\.dismiss) private var dismiss

    private var normalizedDefaultRoutes: [MobileBottomTabKind: PixivRoute] {
        MobileBottomTabConfiguration.defaultRouteMap(
            from: MobileBottomTabConfiguration.storageID(for: defaultRoutes)
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                launchSection
                behaviorSection
                tabDefaultsSection
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle(L10n.bottomTabs)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    dismiss()
                } label: {
                    Label(L10n.done, systemImage: "checkmark")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        defaultRoutes = MobileBottomTabConfiguration.defaultRouteMap
                        launchTarget = MobileBottomTabConfiguration.defaultLaunchTarget
                        remembersLastRoute = MobileBottomTabConfiguration.defaultRemembersLastRoute
                    }
                } label: {
                    Label(L10n.resetBottomTabs, systemImage: "arrow.counterclockwise")
                }
                .help(L10n.resetBottomTabs)
                .accessibilityLabel(L10n.resetBottomTabs)
            }
        }
    }

    private var hero: some View {
        HStack(spacing: 14) {
            Image(systemName: "rectangle.bottomthird.inset.filled")
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 52, height: 52)
                .keiGlass(18)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(L10n.customizeBottomTabs)
                    .font(.title3.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(L10n.bottomTabsHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(24)
    }

    private var launchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.mobileBottomTabLaunchTarget, systemImage: "arrow.up.forward.app")
                .font(.headline)
                .lineLimit(1)

            Text(L10n.mobileBottomTabLaunchHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Menu {
                ForEach(MobileBottomTabLaunchTarget.allCases) { target in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            launchTarget = target
                        }
                    } label: {
                        Label(
                            target.title,
                            systemImage: launchTarget == target ? "checkmark.circle.fill" : target.systemImage
                        )
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: launchTarget.systemImage)
                        .font(.headline.weight(.semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .glassEffect(.regular, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(L10n.mobileBottomTabLaunchTarget)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                        Text(launchTarget.title)
                            .font(.callout.weight(.semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .accessibilityLabel("\(L10n.mobileBottomTabLaunchTarget): \(launchTarget.title)")
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(20)
    }

    private var behaviorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $remembersLastRoute) {
                Label(L10n.rememberMobileBottomTabPages, systemImage: "arrow.trianglehead.2.clockwise")
                    .font(.headline)
                    .lineLimit(2)
            }
            .toggleStyle(.switch)

            Text(L10n.rememberMobileBottomTabPagesHint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(20)
    }

    private var tabDefaultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.defaultTabPages, systemImage: "rectangle.3.group")
                .font(.headline)
                .lineLimit(1)

            VStack(spacing: 10) {
                ForEach(MobileBottomTabKind.allCases) { kind in
                    defaultRouteSlot(for: kind)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(20)
    }

    private func defaultRouteSlot(for kind: MobileBottomTabKind) -> some View {
        let currentRoute = normalizedDefaultRoutes[kind] ?? kind.defaultRoute
        return Menu {
            ForEach(kind.menuSections) { section in
                Section(section.title) {
                    ForEach(section.routes) { route in
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                defaultRoutes = MobileBottomTabConfiguration.replacingDefaultRoute(
                                    for: kind,
                                    with: route,
                                    in: normalizedDefaultRoutes
                                )
                            }
                        } label: {
                            Label(
                                route.title,
                                systemImage: currentRoute == route ? "checkmark.circle.fill" : route.systemImage
                            )
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.systemImage)
                    .font(.headline.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .frame(width: 34, height: 34)
                    .glassEffect(.regular, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(kind.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Label(currentRoute.title, systemImage: currentRoute.systemImage)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .accessibilityLabel("\(kind.title): \(currentRoute.title)")
    }
}
#endif
