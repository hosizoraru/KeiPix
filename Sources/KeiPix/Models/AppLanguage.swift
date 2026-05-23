import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case automatic
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var locale: Locale? {
        switch self {
        case .automatic: nil
        case .simplifiedChinese: Locale(identifier: "zh-Hans")
        case .english: Locale(identifier: "en")
        }
    }

    var lprojName: String? {
        switch self {
        case .automatic: nil
        case .simplifiedChinese: "zh-Hans"
        case .english: "en"
        }
    }

    var title: String {
        switch self {
        case .automatic: L10n.automatic
        case .simplifiedChinese: L10n.simplifiedChinese
        case .english: L10n.english
        }
    }
}
