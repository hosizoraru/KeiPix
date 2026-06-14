import Foundation
#if canImport(Translation)
@preconcurrency import Translation
#endif

// MARK: - Translation language resolver

/// Resolves the target language and session configuration for Apple's
/// Translation framework. Shared by artwork captions, comments, and the novel
/// reader so strategy and language behavior do not drift.
enum TranslationLanguageResolver {
    static func targetLanguage(for targetLanguage: TranslationTargetLanguage) -> Locale.Language? {
        targetLanguage.localeLanguage
    }

    /// Builds a `TranslationSession.Configuration` with the correct target
    /// language. Source is always `nil` for auto-detection.
    #if canImport(Translation)
    static func configuration(for targetLanguage: TranslationTargetLanguage) -> TranslationSession.Configuration {
        let target = Self.targetLanguage(for: targetLanguage)
        if #available(iOS 26.4, macOS 26.4, *) {
            return TranslationSession.Configuration(
                source: nil,
                target: target,
                preferredStrategy: .lowLatency
            )
        }
        return TranslationSession.Configuration(source: nil, target: target)
    }
    #endif
}

enum AppleTranslationReadiness: Equatable, Hashable, Sendable {
    case ready
    case requiresPreparation
    case unavailable(AppleTranslationIssue)
}

enum AppleTranslationIssue: Equatable, Hashable, Sendable {
    case unsupportedSourceLanguage
    case unsupportedTargetLanguage
    case unsupportedLanguagePair
    case unableToIdentifyLanguage
    case nothingToTranslate
    case modelNotInstalled
    case cancelled
    case unavailable

    var localizedMessage: String {
        switch self {
        case .unsupportedSourceLanguage:
            L10n.novelTranslationUnsupportedSourceLanguage
        case .unsupportedTargetLanguage:
            L10n.novelTranslationUnsupportedTargetLanguage
        case .unsupportedLanguagePair:
            L10n.novelTranslationUnsupportedLanguagePair
        case .unableToIdentifyLanguage:
            L10n.novelTranslationCannotIdentifyLanguage
        case .nothingToTranslate:
            L10n.novelTranslationNothingToTranslate
        case .modelNotInstalled:
            L10n.novelTranslationModelNotInstalled
        case .cancelled:
            L10n.novelTranslationCancelled
        case .unavailable:
            L10n.translationFailed
        }
    }
}

enum AppleTranslationReadinessMapper {
    #if canImport(Translation)
    static func readiness(for status: LanguageAvailability.Status) -> AppleTranslationReadiness {
        switch status {
        case .installed:
            .ready
        case .supported:
            .requiresPreparation
        case .unsupported:
            .unavailable(.unsupportedLanguagePair)
        @unknown default:
            .unavailable(.unavailable)
        }
    }

    static func issue(for error: any Error) -> AppleTranslationIssue {
        if error is CancellationError {
            return .cancelled
        }
        if TranslationError.unsupportedSourceLanguage ~= error {
            return .unsupportedSourceLanguage
        }
        if TranslationError.unsupportedTargetLanguage ~= error {
            return .unsupportedTargetLanguage
        }
        if TranslationError.unsupportedLanguagePairing ~= error {
            return .unsupportedLanguagePair
        }
        if TranslationError.unableToIdentifyLanguage ~= error {
            return .unableToIdentifyLanguage
        }
        if TranslationError.nothingToTranslate ~= error {
            return .nothingToTranslate
        }
        if #available(iOS 26.0, macOS 26.0, *) {
            if TranslationError.notInstalled ~= error {
                return .modelNotInstalled
            }
            if TranslationError.alreadyCancelled ~= error {
                return .cancelled
            }
        }
        return .unavailable
    }
    #endif
}

typealias NovelTranslationReadiness = AppleTranslationReadiness
typealias NovelTranslationIssue = AppleTranslationIssue
typealias NovelTranslationReadinessMapper = AppleTranslationReadinessMapper
