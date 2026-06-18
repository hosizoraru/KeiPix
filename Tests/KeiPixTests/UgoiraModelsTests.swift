import Foundation
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

    @Test("Decoder reads only metadata frames from a local ZIP file")
    func decoderReadsMetadataFramesFromLocalZipFile() throws {
        let pngData = try #require(Data(base64Encoded: Self.onePixelPNGBase64))
        let zipData = Self.storedZip(entries: [
            ("000000.jpg", pngData),
            ("000001.jpg", pngData),
            ("unused.txt", Data("not a frame".utf8)),
        ])
        let zipURL = URL.temporaryDirectory
            .appending(path: "keipix-ugoira-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let animation = try UgoiraFrameDecoder.decode(
            zipFileURL: zipURL,
            frames: [
                PixivUgoiraFrame(file: "000001.jpg", delay: 80),
                PixivUgoiraFrame(file: "000000.jpg", delay: 120),
            ]
        )

        #expect(animation.frameCount == 2)
        #expect(animation.frames.map { $0.delayMilliseconds } == [80, 120])
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

    private static let onePixelPNGBase64 =
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII="

    private static func storedZip(entries: [(String, Data)]) -> Data {
        var data = Data()
        var centralDirectory = Data()
        var localHeaderOffsets: [Int] = []

        for (name, body) in entries {
            let nameData = Data(name.utf8)
            let offset = data.count
            localHeaderOffsets.append(offset)
            data.appendLittleEndianUInt32(0x0403_4B50)
            data.appendLittleEndianUInt16(20)
            data.appendLittleEndianUInt16(0)
            data.appendLittleEndianUInt16(0)
            data.appendLittleEndianUInt16(0)
            data.appendLittleEndianUInt16(0)
            data.appendLittleEndianUInt32(0)
            data.appendLittleEndianUInt32(UInt32(body.count))
            data.appendLittleEndianUInt32(UInt32(body.count))
            data.appendLittleEndianUInt16(UInt16(nameData.count))
            data.appendLittleEndianUInt16(0)
            data.append(nameData)
            data.append(body)
        }

        let centralDirectoryOffset = data.count
        for ((name, body), localHeaderOffset) in zip(entries, localHeaderOffsets) {
            let nameData = Data(name.utf8)
            centralDirectory.appendLittleEndianUInt32(0x0201_4B50)
            centralDirectory.appendLittleEndianUInt16(20)
            centralDirectory.appendLittleEndianUInt16(20)
            centralDirectory.appendLittleEndianUInt16(0)
            centralDirectory.appendLittleEndianUInt16(0)
            centralDirectory.appendLittleEndianUInt16(0)
            centralDirectory.appendLittleEndianUInt16(0)
            centralDirectory.appendLittleEndianUInt32(0)
            centralDirectory.appendLittleEndianUInt32(UInt32(body.count))
            centralDirectory.appendLittleEndianUInt32(UInt32(body.count))
            centralDirectory.appendLittleEndianUInt16(UInt16(nameData.count))
            centralDirectory.appendLittleEndianUInt16(0)
            centralDirectory.appendLittleEndianUInt16(0)
            centralDirectory.appendLittleEndianUInt16(0)
            centralDirectory.appendLittleEndianUInt16(0)
            centralDirectory.appendLittleEndianUInt32(0)
            centralDirectory.appendLittleEndianUInt32(UInt32(localHeaderOffset))
            centralDirectory.append(nameData)
        }
        data.append(centralDirectory)

        data.appendLittleEndianUInt32(0x0605_4B50)
        data.appendLittleEndianUInt16(0)
        data.appendLittleEndianUInt16(0)
        data.appendLittleEndianUInt16(UInt16(entries.count))
        data.appendLittleEndianUInt16(UInt16(entries.count))
        data.appendLittleEndianUInt32(UInt32(centralDirectory.count))
        data.appendLittleEndianUInt32(UInt32(centralDirectoryOffset))
        data.appendLittleEndianUInt16(0)
        return data
    }
}

private extension Data {
    mutating func appendLittleEndianUInt16(_ value: UInt16) {
        append(UInt8(value & 0x00FF))
        append(UInt8((value >> 8) & 0x00FF))
    }

    mutating func appendLittleEndianUInt32(_ value: UInt32) {
        append(UInt8(value & 0x0000_00FF))
        append(UInt8((value >> 8) & 0x0000_00FF))
        append(UInt8((value >> 16) & 0x0000_00FF))
        append(UInt8((value >> 24) & 0x0000_00FF))
    }
}
