import Foundation

extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element == PixivTag {
    func uniquedByName() -> [PixivTag] {
        var seen = Set<String>()
        return filter { tag in
            seen.insert(tag.name).inserted
        }
    }

    func prefixArray(_ maxLength: Int) -> [PixivTag] {
        Array(prefix(maxLength))
    }
}

extension Array where Element == String {
    func uniquedCaseInsensitive() -> [String] {
        var seen = Set<String>()
        return filter { value in
            seen.insert(value.lowercased()).inserted
        }
    }
}
