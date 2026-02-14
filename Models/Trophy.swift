import Foundation
import SwiftUI

/// Trofeo sbloccabile della gamification
enum Trophy: String, CaseIterable, Identifiable {
    case firstStep      // Primo prodotto aggiunto
    case fullFridge     // 10+ prodotti in inventario
    case fridgyFriend   // Serie 3 giorni senza sprechi
    case weekClean      // Serie 7 giorni senza sprechi
    case carefulConsumer // 5 consumati in tempo in un mese
    case wasteFighter   // Waste score ≥ 80% in un mese
    case master         // Tutti gli altri trofei sbloccati

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .firstStep: return "trophy.first_step".localized
        case .fullFridge: return "trophy.full_fridge".localized
        case .fridgyFriend: return "trophy.fridgy_friend".localized
        case .weekClean: return "trophy.week_clean".localized
        case .carefulConsumer: return "trophy.careful_consumer".localized
        case .wasteFighter: return "trophy.waste_fighter".localized
        case .master: return "trophy.master".localized
        }
    }

    var displayDescription: String {
        switch self {
        case .firstStep: return "trophy.first_step_desc".localized
        case .fullFridge: return "trophy.full_fridge_desc".localized
        case .fridgyFriend: return "trophy.fridgy_friend_desc".localized
        case .weekClean: return "trophy.week_clean_desc".localized
        case .carefulConsumer: return "trophy.careful_consumer_desc".localized
        case .wasteFighter: return "trophy.waste_fighter_desc".localized
        case .master: return "trophy.master_desc".localized
        }
    }

    /// Icona SF Symbol
    var iconName: String {
        switch self {
        case .firstStep: return "star.fill"
        case .fullFridge: return "refrigerator.fill"
        case .fridgyFriend: return "heart.fill"
        case .weekClean: return "flame.fill"
        case .carefulConsumer: return "checkmark.circle.fill"
        case .wasteFighter: return "leaf.fill"
        case .master: return "crown.fill"
        }
    }

    /// Ordine di visualizzazione (master per ultimo)
    var sortOrder: Int {
        switch self {
        case .firstStep: return 0
        case .fullFridge: return 1
        case .fridgyFriend: return 2
        case .weekClean: return 3
        case .carefulConsumer: return 4
        case .wasteFighter: return 5
        case .master: return 6
        }
    }
    
    /// Livelli/milestone per questo trofeo (es. [1, 5, 10] = 1 prodotto, 5 prodotti, 10 prodotti)
    var levels: [Int] {
        switch self {
        case .firstStep: return [1, 5, 10]
        case .fullFridge: return [10, 20, 30]
        case .fridgyFriend: return [3, 7, 14]
        case .weekClean: return [7, 14, 21]
        case .carefulConsumer: return [5, 10, 20]
        case .wasteFighter: return [80, 90, 95]
        case .master: return [6]
        }
    }
    
    /// Chiave localizzazione unità per i livelli (es. "trophy.level.products", "trophy.level.days")
    var levelUnitKey: String {
        switch self {
        case .firstStep, .fullFridge: return "trophy.level.products"
        case .fridgyFriend, .weekClean: return "trophy.level.days"
        case .carefulConsumer: return "trophy.level.consumed"
        case .wasteFighter: return "trophy.level.percent"
        case .master: return "trophy.level.trophies"
        }
    }

    static var sortedAll: [Trophy] {
        Trophy.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Trofei che devono essere sbloccati per sbloccare Master
    static var requiredForMaster: [Trophy] {
        [.firstStep, .fullFridge, .fridgyFriend, .weekClean, .carefulConsumer, .wasteFighter]
    }
}
