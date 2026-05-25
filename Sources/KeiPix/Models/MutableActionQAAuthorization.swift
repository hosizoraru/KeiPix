import Foundation

enum MutableActionQAAuthorization {
    static let confirmationPhrase = "TEST ACCOUNT"

    static func isAuthorized(_ text: String) -> Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines) == confirmationPhrase
    }
}
