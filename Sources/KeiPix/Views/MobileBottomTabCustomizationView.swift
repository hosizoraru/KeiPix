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
        GlassEffectContainer(spacing: 14) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    launchBehaviorPanel
                    defaultPagesPanel
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 20)
                .frame(maxWidth: 580, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .scrollContentBackground(.hidden)
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

    private var launchBehaviorPanel: some View {
        MobileBottomTabSettingsPanel(
            title: L10n.bottomTabBehavior,
            systemImage: "arrow.up.forward.app"
        ) {
            MobileBottomTabMenuRow(
                title: L10n.mobileBottomTabLaunchTarget,
                value: launchTarget.title,
                systemImage: launchTarget.systemImage
            ) {
                ForEach(MobileBottomTabLaunchTarget.allCases) { target in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            launchTarget = target
                        }
                    } label: {
                        Label(
                            target.title,
                            systemImage: target == launchTarget ? "checkmark" : target.systemImage
                        )
                    }
                }
            }

            MobileBottomTabPanelDivider()

            Toggle(isOn: $remembersLastRoute) {
                MobileBottomTabRowLabel(
                    title: L10n.rememberMobileBottomTabPages,
                    value: nil,
                    systemImage: "arrow.trianglehead.2.clockwise",
                    accessorySystemImage: nil
                )
            }
            .toggleStyle(.switch)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .accessibilityLabel(L10n.rememberMobileBottomTabPages)
        }
    }

    private var defaultPagesPanel: some View {
        MobileBottomTabSettingsPanel(
            title: L10n.defaultTabPages,
            systemImage: "rectangle.3.group"
        ) {
            ForEach(MobileBottomTabKind.allCases) { kind in
                if kind != MobileBottomTabKind.allCases.first {
                    MobileBottomTabPanelDivider()
                }
                defaultRoutePicker(for: kind)
            }
        }
    }

    private func defaultRoutePicker(for kind: MobileBottomTabKind) -> some View {
        let currentRoute = normalizedDefaultRoutes[kind] ?? kind.defaultRoute

        return MobileBottomTabMenuRow(
            title: kind.title,
            value: currentRoute.title,
            systemImage: kind.systemImage
        ) {
            ForEach(kind.menuSections) { section in
                Section(section.title) {
                    ForEach(section.routes) { option in
                        Button {
                            setDefaultRoute(option, for: kind)
                        } label: {
                            Label(
                                option.title,
                                systemImage: option == currentRoute ? "checkmark" : option.systemImage
                            )
                        }
                    }
                }
            }
        }
        .accessibilityLabel("\(kind.title): \(currentRoute.title)")
    }

    private func setDefaultRoute(_ route: PixivRoute, for kind: MobileBottomTabKind) {
        withAnimation(.snappy(duration: 0.18)) {
            let routeMap = MobileBottomTabConfiguration.defaultRouteMap(
                from: MobileBottomTabConfiguration.storageID(for: defaultRoutes)
            )
            defaultRoutes = MobileBottomTabConfiguration.replacingDefaultRoute(
                for: kind,
                with: route,
                in: routeMap
            )
        }
    }
}

private struct MobileBottomTabSettingsPanel<Content: View>: View {
    let title: String
    let systemImage: String
    private let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .symbolRenderingMode(.hierarchical)
                .lineLimit(1)
                .minimumScaleFactor(0.86)
                .padding(.horizontal, 14)
                .padding(.top, 13)
                .padding(.bottom, 8)

            VStack(spacing: 0) {
                content
            }
            .padding(.bottom, 5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiPanel(22)
    }
}

private struct MobileBottomTabMenuRow<Content: View>: View {
    let title: String
    let value: String
    let systemImage: String
    private let content: Content

    init(
        title: String,
        value: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.value = value
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        Menu {
            content
        } label: {
            MobileBottomTabRowLabel(
                title: title,
                value: value,
                systemImage: systemImage,
                accessorySystemImage: "chevron.up.chevron.down"
            )
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .tint(.primary)
    }
}

private struct MobileBottomTabRowLabel: View {
    let title: String
    let value: String?
    let systemImage: String
    let accessorySystemImage: String?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            MobileBottomTabIcon(systemImage: systemImage)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    titleText
                    valueText
                }

                VStack(alignment: .leading, spacing: 3) {
                    titleText
                    valueText
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let accessorySystemImage {
                Image(systemName: accessorySystemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.86)
    }

    @ViewBuilder
    private var valueText: some View {
        if let value,
           value.isEmpty == false,
           value != title {
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .minimumScaleFactor(0.82)
        }
    }
}

private struct MobileBottomTabIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.callout.weight(.semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
            .accessibilityHidden(true)
    }
}

private struct MobileBottomTabPanelDivider: View {
    var body: some View {
        Divider()
            .opacity(0.45)
            .padding(.leading, 56)
    }
}
#endif
