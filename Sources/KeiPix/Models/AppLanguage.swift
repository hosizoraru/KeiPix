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
