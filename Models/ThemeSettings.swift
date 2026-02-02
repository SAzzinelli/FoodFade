import Foundation
import SwiftData

/// Enum per il colore principale d'accento
enum AccentColor: String, Codable, CaseIterable {
    case `default` = "default"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case orange = "orange"
    case pink = "pink"
    case teal = "teal"
    
    var displayName: String {
        switch self {
        case .default: return "Default"
        case .green: return "Verde"
        case .blue: return "Blu"
        case .purple: return "Viola"
        case .orange: return "Arancione"
        case .pink: return "Rosa"
        case .teal: return "Azzurro"
        }
    }
}

/// Enum per la modalità di aspetto
enum AppearanceMode: String, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
        switch self {
        case .system: return "Sistema"
        case .light: return "Chiaro"
        case .dark: return "Scuro"
        }
    }
}

/// Enum per la modalità dell'anello di progresso
enum ProgressRingMode: String, Codable, CaseIterable {
    case safeItems = "safeItems"        // % prodotti "tutto ok" (default)
    case atRisk = "atRisk"             // % prodotti a rischio (invertito)
    case healthScore = "healthScore"   // Health score basato su consumati vs scaduti
    
    var displayName: String {
        switch self {
        case .safeItems: return "Prodotti sicuri"
        case .atRisk: return "Prodotti a rischio"
        case .healthScore: return "Health score"
        }
    }
    
    var description: String {
        switch self {
        case .safeItems: return "Mostra la percentuale di prodotti che scadono dopo 3+ giorni"
        case .atRisk: return "Mostra la percentuale di prodotti che scadono presto o sono scaduti"
        case .healthScore: return "Mostra un punteggio basato su prodotti consumati vs scaduti"
        }
    }
}