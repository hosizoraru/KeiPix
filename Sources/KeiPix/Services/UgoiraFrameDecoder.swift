import AppKit
import Foundation
import ZIPFoundation

enum UgoiraFrameDecoder {
    static func decode(zipData: Data, metadata: PixivUgoiraMetadata) throws -> UgoiraAnimation {
        let archive = try Archive(data: zipData, accessMode: .read)

        var imageDataByName: [String: Data] = [:]
        for entry in archive where entry.type == .file {
            var data = Data()
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }
            imageDataByName[entry.path] = data
        }

        let frames = metadata.frames.compactMap { frame -> UgoiraAnimationFrame? in
            guard let data = imageDataByName[frame.file],
                  let image = NSImage(data: data) else {
                return nil
            }
            return UgoiraAnimationFrame(
                image: image,
                delay: .milliseconds(max(frame.delay, 1))
            )
        }

        guard frames.isEmpty == false else {
            throw PixivAPIError.invalidResponse
        }
        return UgoiraAnimation(frames: frames)
    }
}
