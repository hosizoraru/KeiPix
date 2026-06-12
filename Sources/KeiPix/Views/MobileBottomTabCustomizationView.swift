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
        List {
            hero
                .mobileBottomTabListRow(top: 12, bottom: 8)
            launchSection
            behaviorSection
            tabDefaultsSection
        }
        .listStyle(.plain)
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
        Section {
            NavigationLink {
                MobileBottomTabLaunchTargetSelectionView(selection: $launchTarget)
            } label: {
                MobileBottomTabSummaryRow(
                    eyebrow: L10n.mobileBottomTabLaunchTarget,
                    title: launchTarget.title,
                    systemImage: launchTarget.systemImage
                )
            }
            .accessibilityLabel("\(L10n.mobileBottomTabLaunchTarget): \(launchTarget.title)")
            .mobileBottomTabListRow()
        } header: {
            MobileBottomTabSectionHeader(
                title: L10n.mobileBottomTabLaunchTarget,
                systemImage: "arrow.up.forward.app"
            )
        } footer: {
            MobileBottomTabSectionFooter(text: L10n.mobileBottomTabLaunchHint)
        }
    }

    private var behaviorSection: some View {
        Section {
            Toggle(isOn: $remembersLastRoute) {
                Label(L10n.rememberMobileBottomTabPages, systemImage: "arrow.trianglehead.2.clockwise")
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
            }
            .toggleStyle(.switch)
            .mobileBottomTabListRow()
        } footer: {
            MobileBottomTabSectionFooter(text: L10n.rememberMobileBottomTabPagesHint)
        }
    }

    private var tabDefaultsSection: some View {
        Section {
            ForEach(MobileBottomTabKind.allCases) { kind in
                defaultRouteSlot(for: kind)
            }
        } header: {
            MobileBottomTabSectionHeader(
                title: L10n.defaultTabPages,
                systemImage: "rectangle.3.group"
            )
        }
    }

    private func defaultRouteSlot(for kind: MobileBottomTabKind) -> some View {
        let currentRoute = normalizedDefaultRoutes[kind] ?? kind.defaultRoute
        return NavigationLink {
            MobileBottomTabRouteSelectionView(
                kind: kind,
                route: defaultRouteBinding(for: kind)
            )
        } label: {
            MobileBottomTabSummaryRow(
                eyebrow: kind.title,
                title: currentRoute.title,
                systemImage: currentRoute.systemImage
            )
        }
        .accessibilityLabel("\(kind.title): \(currentRoute.title)")
        .mobileBottomTabListRow()
    }

    private func defaultRouteBinding(for kind: MobileBottomTabKind) -> Binding<PixivRoute> {
        Binding {
            normalizedDefaultRoutes[kind] ?? kind.defaultRoute
        } set: { route in
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
}

private struct MobileBottomTabLaunchTargetSelectionView: View {
    @Binding var selection: MobileBottomTabLaunchTarget
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(MobileBottomTabLaunchTarget.allCases) { target in
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        selection = target
                    }
                    dismiss()
                } label: {
                    MobileBottomTabSelectionOptionRow(
                        title: target.title,
                        systemImage: target.systemImage,
                        isSelected: selection == target
                    )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == target ? .isSelected : [])
                .mobileBottomTabListRow()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(L10n.mobileBottomTabLaunchTarget)
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

private struct MobileBottomTabRouteSelectionView: View {
    let kind: MobileBottomTabKind
    @Binding var route: PixivRoute
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(kind.menuSections) { section in
                Section {
                    ForEach(section.routes) { option in
                        Button {
                            withAnimation(.snappy(duration: 0.18)) {
                                route = option
                            }
                            dismiss()
                        } label: {
                            MobileBottomTabSelectionOptionRow(
                                title: option.title,
                                systemImage: option.systemImage,
                                isSelected: route == option
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(route == option ? .isSelected : [])
                        .mobileBottomTabListRow()
                    }
                } header: {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

private struct MobileBottomTabSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.primary)
            .lineLimit(1)
            .textCase(nil)
    }
}

private struct MobileBottomTabSectionFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .textCase(nil)
    }
}

private struct MobileBottomTabSummaryRow: View {
    let eyebrow: String
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 34, height: 34)
                .glassEffect(.regular, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

private struct MobileBottomTabSelectionOptionRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 34, height: 34)
                .glassEffect(.regular, in: Circle())

            Text(title)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.headline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func mobileBottomTabListRow(top: CGFloat = 5, bottom: CGFloat = 5) -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: top, leading: 16, bottom: bottom, trailing: 16))
    }
}
#endif
