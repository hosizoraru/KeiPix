import SwiftUI

/// QuickTime-style transport bar for `UgoiraPlayer`. Mirrors the macOS
/// HIG layout for media controls: leading play/pause, a scrubber that
/// occupies the available width, a trailing time read-out, then a
/// configurable trailing slot for export / reload menus. The bar lives
/// **below** the artwork — overlaying chrome on top of an animated
/// frame is what made the original viewer look noisy and crowded.
///
/// All controls share glass styling so the user reads them as one
/// transport group instead of a stack of plain and prominent controls
/// fighting for hierarchy.
struct UgoiraPlaybackBar<TrailingActions: View>: View {
    @Bindable var player: UgoiraPlayer
    var trailingActions: () -> TrailingActions

    init(
        player: UgoiraPlayer,
        @ViewBuilder trailingActions: @escaping () -> TrailingActions = { EmptyView() }
    ) {
        self.player = player
        self.trailingActions = trailingActions
    }

    var body: some View {
        HStack(spacing: 12) {
            playPauseButton

            scrubber

            timeReadout

            speedPicker

            trailingActions()
        }
        .controlSize(.small)
        .platformGlassControlBar(verticalPadding: 8, topPadding: 6, bottomPadding: 8)
    }

    // MARK: - Play / pause

    private var playPauseButton: some View {
        Button {
            player.togglePlayback()
        } label: {
            Label(
                player.isPlaying ? L10n.pauseUgoira : L10n.playUgoira,
                systemImage: player.isPlaying ? "pause.fill" : "play.fill"
            )
        }
        .os26GlassIconButton(prominent: true)
        .controlSize(.regular)
        .keyboardShortcut(.space, modifiers: [])
        .help(player.isPlaying ? L10n.pauseUgoira : L10n.playUgoira)
        .accessibilityLabel(player.isPlaying ? L10n.pauseUgoira : L10n.playUgoira)
        .disabled(player.hasContent == false)
    }

    // MARK: - Scrubber

    private var scrubber: some View {
        Slider(
            value: scrubberBinding,
            in: scrubberRange,
            step: 1
        )
        .labelsHidden()
        .help(L10n.ugoiraSeek)
        .accessibilityLabel(L10n.ugoiraSeek)
        .accessibilityValue(player.positionSummary)
        .disabled(player.hasContent == false)
    }

    private var scrubberRange: ClosedRange<Double> {
        // SwiftUI's `Slider` rejects an empty range; clamp to a single-
        // tick range when the animation hasn't loaded so the disabled
        // bar still has a valid skeleton.
        let upper = max(0, player.frameCount - 1)
        return 0...Double(max(upper, 1))
    }

    private var scrubberBinding: Binding<Double> {
        Binding(
            get: { Double(player.currentFrameIndex) },
            set: { player.seek(to: Int($0.rounded())) }
        )
    }

    // MARK: - Time read-out

    private var timeReadout: some View {
        Text(player.positionSummary)
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .frame(minWidth: 96, alignment: .trailing)
            .accessibilityLabel(L10n.ugoiraTimeline)
            .accessibilityValue(player.positionSummary)
    }

    // MARK: - Speed picker

    private var speedPicker: some View {
        Picker(L10n.playbackSpeed, selection: $player.playbackSpeed) {
            ForEach(UgoiraPlaybackSpeed.allCases) { speed in
                Text(speed.title).tag(speed)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .help(L10n.playbackSpeed)
        .accessibilityLabel(L10n.playbackSpeed)
        .disabled(player.hasContent == false)
    }
}
