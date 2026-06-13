import Foundation

struct ReaderImageTransform: Equatable, Sendable {
    static let identity = ReaderImageTransform()

    var quarterTurns: Int
    var isFlippedHorizontally: Bool
    var isFlippedVertically: Bool

    init(
        quarterTurns: Int = 0,
        isFlippedHorizontally: Bool = false,
        isFlippedVertically: Bool = false
    ) {
        self.quarterTurns = Self.normalizedQuarterTurns(quarterTurns)
        self.isFlippedHorizontally = isFlippedHorizontally
        self.isFlippedVertically = isFlippedVertically
    }

    var rotationDegrees: Double {
        Double(quarterTurns * 90)
    }

    var isIdentity: Bool {
        quarterTurns == 0
            && isFlippedHorizontally == false
            && isFlippedVertically == false
    }

    mutating func rotateLeft() {
        quarterTurns = Self.normalizedQuarterTurns(quarterTurns - 1)
    }

    mutating func rotateRight() {
        quarterTurns = Self.normalizedQuarterTurns(quarterTurns + 1)
    }

    mutating func flipHorizontal() {
        isFlippedHorizontally.toggle()
    }

    mutating func flipVertical() {
        isFlippedVertically.toggle()
    }

    mutating func reset() {
        self = .identity
    }

    private static func normalizedQuarterTurns(_ turns: Int) -> Int {
        let remainder = turns % 4
        return remainder >= 0 ? remainder : remainder + 4
    }
}
