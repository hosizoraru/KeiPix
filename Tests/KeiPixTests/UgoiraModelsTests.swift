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
}
