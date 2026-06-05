#if os(iOS)
import SwiftUI

struct MobileBottomTabCustomizationView: View {
    @Binding var items: [MobileBottomTabItem]
    @Environment(\.dismiss) private var dismiss

    private var normalizedItems: [MobileBottomTabItem] {
        MobileBottomTabConfiguration.items(from: MobileBottomTabConfiguration.storageID(for: items))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                hero
                fixedTabsSection
                selectedDestinationsSection
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
                        items = MobileBottomTabConfiguration.defaultItems
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

    private var fixedTabsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.fixedTabs, systemImage: "lock")
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 10) {
                fixedTabChip(title: L10n.feed, systemImage: "photo.on.rectangle.angled")
                fixedTabChip(title: L10n.search, systemImage: "magnifyingglass")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(20)
    }

    private func fixedTabChip(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.callout.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: Capsule(style: .continuous))
            .accessibilityLabel(title)
    }

    private var selectedDestinationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(L10n.selectedDestinations, systemImage: "rectangle.3.group")
                .font(.headline)
                .lineLimit(1)

            VStack(spacing: 10) {
                ForEach(0..<MobileBottomTabConfiguration.maximumCustomItemCount, id: \.self) { index in
                    destinationSlot(index: index)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keiGlass(20)
    }

    private func destinationSlot(index: Int) -> some View {
        let currentItem = normalizedItems[index]
        return Menu {
            ForEach(MobileBottomTabItem.allCases) { candidate in
                Button {
                    withAnimation(.snappy(duration: 0.18)) {
                        items = MobileBottomTabConfiguration.replacing(
                            itemAt: index,
                            with: candidate,
                            in: normalizedItems
                        )
                    }
                } label: {
                    Label(
                        candidate.title,
                        systemImage: currentItem == candidate ? "checkmark.circle.fill" : candidate.systemImage
                    )
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: L10n.bottomTabSlotFormat, index + 1))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Label(currentItem.title, systemImage: currentItem.systemImage)
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
        .accessibilityLabel(String(format: L10n.bottomTabSlotFormat, index + 1))
    }
}
#endif
