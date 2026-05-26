import SwiftUI

struct ReadingSettingsPage: View {
    @Bindable var store: KeiPixStore

    var body: some View {
        Form {
            Section {
                Picker(L10n.defaultArtworkReadingMode, selection: store.settings_defaultArtworkReadingModeBinding) {
                    ForEach(ArtworkReadingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Picker(L10n.defaultMangaReadingMode, selection: store.settings_defaultMangaReadingModeBinding) {
                    ForEach(ArtworkReadingMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(L10n.restoreLastReadPage, isOn: store.settings_restoreReaderProgressBinding)
            } header: {
                Text(L10n.readingWindow)
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.defaultReadingModeHint)
                    Text(L10n.restoreLastReadPageHint)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section {
                Toggle(L10n.enableTrackpadGestures, isOn: store.settings_trackpadGesturesBinding)

                Picker(L10n.twoFingerSwipeBehavior, selection: store.settings_horizontalSwipeBehaviorBinding) {
                    ForEach(TrackpadHorizontalSwipeBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .pickerStyle(.menu)
            } header: {
                Text(L10n.trackpad)
            }
        }
        .formStyle(.grouped)
        .navigationTitle(L10n.readingWindow)
    }
}
