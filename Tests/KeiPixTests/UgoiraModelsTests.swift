import Testing
@testable import KeiPix

@Suite("Ugoira models")
struct UgoiraModelsTests {
    @Test("Playback speeds adjust frame delays")
    func playbackSpeedAdjustedDelays() {
        #expect(UgoiraPlaybackSpeed.half.adjustedDelayMilliseconds(100) == 200)
        #expect(UgoiraPlaybackSpeed.normal.adjustedDelayMilliseconds(100) == 100)
        #expect(UgoiraPlaybackSpeed.fast.adjustedDelayMilliseconds(90) == 60)
        #expect(UgoiraPlaybackSpeed.double.adjustedDelayMilliseconds(100) == 50)
        #expect(UgoiraPlaybackSpeed.double.adjustedDelayMilliseconds(1) == 1)
    }

    @Test("Visual QA animation has exportable local frames")
    func visualQAAnimationFrames() {
        let package = UgoiraExportPackage.visualQASample

        #expect(package.animation.frameCount == 4)
        #expect(package.animation.totalDurationMilliseconds == 560)
        #expect(package.metadata.frames.map(\.delay) == [140, 140, 140, 140])
        #expect(package.zipData.isEmpty == false)
    }

    @Test("Player install resets frame and parks transport in a paused ready state")
    @MainActor
    func playerInstallResetsState() {
        let player = UgoiraPlayer()

        #expect(player.hasContent == false)
        #expect(player.isLoading == false)

        player.beginLoading()
        #expect(player.isLoading == true)

        player.install(UgoiraAnimation.visualQASample, autoplay: false)
        #expect(player.hasContent == true)
        #expect(player.isPlaying == false)
        #expect(player.currentFrameIndex == 0)
        #expect(player.frameCount == 4)
    }

    @Test("Player seek clamps within frame range")
    @MainActor
    func playerSeekClamps() {
        let player = UgoiraPlayer()
        player.install(UgoiraAnimation.visualQASample, autoplay: false)

        player.seek(to: 2)
        #expect(player.currentFrameIndex == 2)

        player.seek(to: -10)
        #expect(player.currentFrameIndex == 0)

        player.seek(to: 999)
        #expect(player.currentFrameIndex == player.frameCount - 1)
    }

    @Test("Player failure surfaces a message and clears playback")
    @MainActor
    func playerFailureClearsPlayback() {
        let player = UgoiraPlayer()
        player.install(UgoiraAnimation.visualQASample, autoplay: false)

        player.reportFailure("network down")

        #expect(player.hasContent == false)
        #expect(player.isPlaying == false)
        #expect(player.failureMessage == "network down")
    }

    @Test("Player position summary formats frames and duration")
    @MainActor
    func playerPositionSummaryFormats() {
        let player = UgoiraPlayer()
        #expect(player.positionSummary == "—")

        player.install(UgoiraAnimation.visualQASample, autoplay: false)
        #expect(player.positionSummary == "1 / 4 · 0.6s")

        player.seek(to: 3)
        #expect(player.positionSummary == "4 / 4 · 0.6s")
    }
}
