import AppKit
import Compression
import Foundation

enum UgoiraFrameDecoder {
    static func decode(zipData: Data, metadata: PixivUgoiraMetadata) throws -> UgoiraAnimation {
        try decode(zipData: zipData, frames: metadata.frames)
    }

    static func decode(zipData: Data, frames metadataFrames: [PixivUgoiraFrame]) throws -> UgoiraAnimation {
        let imageDataByName = try UgoiraZipArchive.extractFiles(from: zipData)

        let frames = metadataFrames.compactMap { frame -> UgoiraAnimationFrame? in
            guard let data = imageDataByName[frame.file],
                  let image = NSImage(data: data) else {
                return nil
            }
            let delayMilliseconds = max(frame.delay, 1)
            return UgoiraAnimationFrame(
                image: image,
                delay: .milliseconds(delayMilliseconds),
                delayMilliseconds: delayMilliseconds
            )
        }

        guard frames.isEmpty == false else {
            throw PixivAPIError.invalidResponse
        }
        return UgoiraAnimation(frames: frames)
    }
}

private enum UgoiraZipArchive {
    private static let localFileHeaderSignature: UInt32 = 0x0403_4B50
    private static let centralFileHeaderSignature: UInt32 = 0x0201_4B50
    private static let endOfCentralDirectorySignature: UInt32 = 0x0605_4B50

    static func extractFiles(from data: Data) throws -> [String: Data] {
        let centralDirectory = try centralDirectoryRange(in: data)
        var files: [String: Data] = [:]
        var offset = centralDirectory.lowerBound

        while offset < centralDirectory.upperBound {
            guard try data.littleEndianUInt32(at: offset) == centralFileHeaderSignature else {
                throw PixivAPIError.invalidResponse
            }

            let flags = try data.littleEndianUInt16(at: offset + 8)
            guard flags & 0x0001 == 0 else {
                throw PixivAPIError.invalidResponse
            }

            let compressionMethod = try data.littleEndianUInt16(at: offset + 10)
            let compressedSize = try Int.checked(data.littleEndianUInt32(at: offset + 20))
            let uncompressedSize = try Int.checked(data.littleEndianUInt32(at: offset + 24))
            let fileNameLength = Int(try data.littleEndianUInt16(at: offset + 28))
            let extraFieldLength = Int(try data.littleEndianUInt16(at: offset + 30))
            let fileCommentLength = Int(try data.littleEndianUInt16(at: offset + 32))
            let localHeaderOffset = try Int.checked(data.littleEndianUInt32(at: offset + 42))

            let fileNameStart = offset + 46
            let fileNameData = try data.checkedSubdata(in: fileNameStart..<(fileNameStart + fileNameLength))
            let fileName = String(data: fileNameData, encoding: .utf8)
                ?? String(data: fileNameData, encoding: .isoLatin1)
                ?? ""

            offset = fileNameStart + fileNameLength + extraFieldLength + fileCommentLength

            guard fileName.isEmpty == false, fileName.hasSuffix("/") == false else {
                continue
            }

            files[fileName] = try extractFile(
                from: data,
                localHeaderOffset: localHeaderOffset,
                compressionMethod: compressionMethod,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize
            )
        }

        return files
    }

    private static func centralDirectoryRange(in data: Data) throws -> Range<Int> {
        guard data.count >= 22 else { throw PixivAPIError.invalidResponse }

        let minimumOffset = max(0, data.count - 22 - 65_535)
        for offset in stride(from: data.count - 22, through: minimumOffset, by: -1) {
            guard try data.littleEndianUInt32(at: offset) == endOfCentralDirectorySignature else {
                continue
            }

            let directorySize = try Int.checked(data.littleEndianUInt32(at: offset + 12))
            let directoryOffset = try Int.checked(data.littleEndianUInt32(at: offset + 16))
            let directoryEnd = directoryOffset + directorySize
            guard directoryOffset >= 0, directoryEnd <= data.count else {
                throw PixivAPIError.invalidResponse
            }
            return directoryOffset..<directoryEnd
        }

        throw PixivAPIError.invalidResponse
    }

    private static func extractFile(
        from data: Data,
        localHeaderOffset: Int,
        compressionMethod: UInt16,
        compressedSize: Int,
        uncompressedSize: Int
    ) throws -> Data {
        guard try data.littleEndianUInt32(at: localHeaderOffset) == localFileHeaderSignature else {
            throw PixivAPIError.invalidResponse
        }

        let fileNameLength = Int(try data.littleEndianUInt16(at: localHeaderOffset + 26))
        let extraFieldLength = Int(try data.littleEndianUInt16(at: localHeaderOffset + 28))
        let dataStart = localHeaderOffset + 30 + fileNameLength + extraFieldLength
        let compressedData = try data.checkedSubdata(in: dataStart..<(dataStart + compressedSize))

        switch compressionMethod {
        case 0:
            return compressedData
        case 8:
            return try inflateRawDeflate(compressedData, uncompressedSize: uncompressedSize)
        default:
            throw PixivAPIError.invalidResponse
        }
    }

    private static func inflateRawDeflate(_ data: Data, uncompressedSize: Int) throws -> Data {
        guard uncompressedSize > 0 else { return Data() }

        var output = [UInt8](repeating: 0, count: uncompressedSize)
        let bytesWritten = data.withUnsafeBytes { sourceBuffer in
            output.withUnsafeMutableBytes { destinationBuffer in
                compression_decode_buffer(
                    destinationBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    uncompressedSize,
                    sourceBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard bytesWritten == uncompressedSize else {
            throw PixivAPIError.invalidResponse
        }
        return Data(output)
    }
}

private extension Data {
    func checkedSubdata(in range: Range<Int>) throws -> Data {
        guard range.lowerBound >= 0, range.upperBound <= count, range.lowerBound <= range.upperBound else {
            throw PixivAPIError.invalidResponse
        }
        return subdata(in: range)
    }

    func littleEndianUInt16(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else { throw PixivAPIError.invalidResponse }
        return UInt16(self[startIndex + offset])
            | (UInt16(self[startIndex + offset + 1]) << 8)
    }

    func littleEndianUInt32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= count else { throw PixivAPIError.invalidResponse }
        return UInt32(self[startIndex + offset])
            | (UInt32(self[startIndex + offset + 1]) << 8)
            | (UInt32(self[startIndex + offset + 2]) << 16)
            | (UInt32(self[startIndex + offset + 3]) << 24)
    }
}

private extension Int {
    static func checked<T: BinaryInteger>(_ value: T) throws -> Int {
        guard let converted = Int(exactly: value) else {
            throw PixivAPIError.invalidResponse
        }
        return converted
    }
}
