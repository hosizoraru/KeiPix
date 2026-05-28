import Foundation

/// Structured error type for KeiPix.
///
/// Replaces the generic `errorMessage: String?` pattern with typed
/// errors that carry retry actions, user-facing messages, and
/// error categorization for better UX.
enum AppError: Identifiable, Equatable {
    case network(underlying: String, retryable: Bool)
    case auth(message: String)
    case parsing(message: String)
    case notFound(message: String)
    case rateLimited(retryAfter: TimeInterval?)
    case unknown(message: String)

    var id: String {
        switch self {
        case .network: return "network"
        case .auth: return "auth"
        case .parsing: return "parsing"
        case .notFound: return "notFound"
        case .rateLimited: return "rateLimited"
        case .unknown: return "unknown"
        }
    }

    /// User-facing error message.
    var displayMessage: String {
        switch self {
        case .network(let msg, _): return msg
        case .auth(let msg): return msg
        case .parsing(let msg): return msg
        case .notFound(let msg): return msg
        case .rateLimited: return L10n.errorRateLimited
        case .unknown(let msg): return msg
        }
    }

    /// Whether the error can be retried.
    var isRetryable: Bool {
        switch self {
        case .network(_, let retryable): return retryable
        case .rateLimited: return true
        case .auth, .parsing, .notFound: return false
        case .unknown: return false
        }
    }

    /// System image for the error category.
    var systemImage: String {
        switch self {
        case .network: return "wifi.exclamationmark"
        case .auth: return "lock.shield"
        case .parsing: return "doc.text.magnifyingglass"
        case .notFound: return "questionmark.folder"
        case .rateLimited: return "clock.badge.exclamationmark"
        case .unknown: return "exclamationmark.triangle"
        }
    }

    // MARK: - Equatable

    static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id && lhs.displayMessage == rhs.displayMessage
    }
}

// MARK: - Convenience initializers

extension AppError {
    /// Create from a generic Error.
    static func from(_ error: Error) -> AppError {
        let message = error.localizedDescription
        if message.contains("Internet") || message.contains("network") || message.contains("timed out") {
            return .network(underlying: message, retryable: true)
        }
        if message.contains("401") || message.contains("403") || message.contains("unauthorized") {
            return .auth(message: message)
        }
        if message.contains("404") || message.contains("not found") {
            return .notFound(message: message)
        }
        if message.contains("429") || message.contains("rate limit") {
            return .rateLimited(retryAfter: nil)
        }
        return .unknown(message: message)
    }

    /// Create from a Pixiv API error.
    static func fromPixivAPI(_ error: Error) -> AppError {
        let message = error.localizedDescription
        if message.contains("invalid_grant") || message.contains("expired") {
            return .auth(message: L10n.errorSessionExpired)
        }
        return .from(error)
    }
}
