import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case automatic
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case english

    var id: String { rawValue }

    var locale: Locale? {
        switch self {
        case .automatic: nil
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        case .traditionalChinese: Locale(identifier: "zh-Hant")
        case .japanese: Locale(identifier: "ja")
        case .english: Locale(identifier: "en")
        }
    }

    var lprojName: String? {
        switch self {
        case .automatic: nil
        case .simplifiedChinese: "zh-Hans"
        case .traditionalChinese: "zh-Hant"
        case .japanese: "ja"
        case .english: "en"
        }
    }

    var title: String {
        switch self {
        case .automatic: L10n.automatic
        case .simplifiedChinese: L10n.simplifiedChinese
        case .traditionalChinese: L10n.traditionalChinese
        case .japanese: L10n.japanese
        case .english: L10n.english
        }
    }
}

// MARK: - Translation target language

/// User-facing option for the translation target language.
/// `.system` follows the device locale; the explicit cases let users
/// override when the automatic detection picks the wrong language.
enum TranslationTargetLanguage: String, CaseIterable, Identifiable, Codable {
    case system
    case simplifiedChinese
    case traditionalChinese
    case japanese
    case english

    var id: String { rawValue }

    /// Maps to a `Locale.Language` for `TranslationSession.Configuration`.
    /// Returns `nil` for `.system` so the framework uses the device locale.
    var localeLanguage: Locale.Language? {
        switch self {
        case .system: nil
        case .simplifiedChinese: Locale.Language(identifier: "zh-Hans")
        case .traditionalChinese: Locale.Language(identifier: "zh-Hant")
        case .japanese: Locale.Language(identifier: "ja")
        case .english: Locale.Language(identifier: "en")
        }
    }

    var title: String {
        switch self {
        case .system: L10n.translationTargetSystem
        case .simplifiedChinese: L10n.simplifiedChinese
        case .traditionalChinese: L10n.traditionalChinese
        case .japanese: L10n.japanese
        case .english: L10n.english
        }
    }
}
