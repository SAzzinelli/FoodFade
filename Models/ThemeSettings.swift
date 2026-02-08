import Foundation
import SwiftData

/// Enum per il colore principale d'accento
enum AccentColor: String, Codable, CaseIterable {
    case natural = "natural"
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case orange = "orange"
    case pink = "pink"
    case teal = "teal"
    
    var displayName: String {
        switch self {
        case .natural: return "Naturale"
        case .green: return "Verde"
        case .blue: return "Blu"
        case .purple: return "Viola"
        case .orange: return "Arancione"
        case .pink: return "Rosa"
        case .teal: return "Azzurro"
        }
    }
}

/// Contesto per icone in stile Naturale (colori semantici)
enum SemanticIconContext {
    case tagGlutenFree
    case tagBio
    case category(FoodCategory)
    case foodType(FoodType)
    case settingsRing
    case settingsAlerts
    case settingsCalendar
    case settingsExpirationInput
    case settingsSuggestions
    case settingsAvailable
    case settingsGear
    case settingsAppearance
    case settingsCloud
    case settingsBackup
    case settingsInfo
    case settingsReset
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

/// Stile del riepilogo in Home: anello con percentuale oppure solo testo
enum HomeSummaryStyle: String, Codable, CaseIterable {
    case ring = "ring"           // Anello con % e messaggi
    case compact = "compact"     // Solo riepilogo testuale (niente anello)
    
    var displayName: String {
        switch self {
        case .ring: return "Anello"
        case .compact: return "Solo riepilogo"
        }
    }
    
    var description: String {
        switch self {
        case .ring: return "Mostra l'anello con percentuale e messaggio"
        case .compact: return "Mostra solo i numeri (es. 1 da consumare · 1 tutto ok)"
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

/// Modalità di inserimento della data di scadenza
enum ExpirationInputMethod: String, Codable, CaseIterable {
    case calendar = "calendar"
    case dictation = "dictation"
    
    var displayName: String {
        switch self {
        case .calendar: return "settings.expiration.calendar".localized
        case .dictation: return "settings.expiration.dictation".localized
        }
    }
}

// MARK: - Fridgy emozioni (mascotte assistant-style)
/// Quando mostrare quale espressione di Fridgy
enum FridgyEmotion: String, CaseIterable {
    case triste   // Cibo scaduto, attenzione richiesta
    case sonno    // Ok ma puoi fare meglio (noia, stato neutro)
    case avanti   // Incoraggiamento, vai avanti
    case bravo    // Premio per qualcosa di molto positivo
    case amore    // Tutto fatto alla perfezione
    
    var imageName: String {
        switch self {
        case .triste: return "FridgyTriste"
        case .sonno: return "FridgySonno"
        case .avanti: return "FridgyAvanti"
        case .bravo: return "FridgyBravo"
        case .amore: return "FridgyAmore"
        }
    }
    
    /// Emozione per la Home in base ai conteggi (nil = non mostrare Fridgy)
    static func forHomeSummary(expiringToday: Int, toConsume: Int, incoming: Int, allOk: Int, total: Int) -> FridgyEmotion? {
        guard total > 0 else { return .avanti }
        let urgent = expiringToday + toConsume
        if urgent > 0 { return .triste }
        if allOk > 0 && incoming == 0 { return .amore }
        if incoming > 0 { return .sonno }
        return .avanti
    }
    
    /// Emozione per le Statistiche in base al Waste Score (0...1, 1 = nessuno spreco)
    static func forWasteScore(_ score: Double) -> FridgyEmotion {
        if score >= 0.8 { return .amore }
        if score >= 0.5 { return .bravo }
        if score >= 0.3 { return .sonno }
        return .triste
    }
}