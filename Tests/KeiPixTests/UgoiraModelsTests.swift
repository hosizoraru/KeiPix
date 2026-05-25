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
}
