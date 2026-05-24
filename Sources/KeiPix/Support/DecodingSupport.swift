import Foundation

extension KeyedDecodingContainer {
    func decodeCleanURLIfPresent(forKey key: Key) -> URL? {
        let value = (try? decodeIfPresent(String.self, forKey: key)) ?? nil
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }
        return URL(string: trimmed)
    }
}
