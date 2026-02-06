import SwiftUI
import Combine

/// Manager per il tema dell'app con supporto per colori personalizzati
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var accentColor: AccentColor = .natural
    @Published var animationsEnabled: Bool = true
    @Published var appearanceMode: AppearanceMode = .system
    
    private init() {}
    
    /// Stile Naturale: icone variegate e testi neri (non un solo colore accent).
    var isNaturalStyle: Bool { accentColor == .natural }
    
    /// Ottiene il colore principale basato sulla selezione. In stile Naturale è nero (testi/bordi).
    var primaryColor: Color {
        switch accentColor {
        case .natural:
            return Color.primary
        case .green:
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .blue:
            return Color(red: 0.3, green: 0.6, blue: 1.0)
        case .purple:
            return Color(red: 0.7, green: 0.4, blue: 1.0)
        case .orange:
            return Color(red: 1.0, green: 0.6, blue: 0.2)
        case .pink:
            return Color(red: 1.0, green: 0.4, blue: 0.6)
        case .teal:
            return Color(red: 0.2, green: 0.7, blue: 0.8)
        }
    }
    
    /// Ottiene il colore principale scuro
    var primaryColorDark: Color {
        switch accentColor {
        case .natural:
            return Color.primary
        case .green:
            return Color(red: 0.15, green: 0.7, blue: 0.35)
        case .blue:
            return Color(red: 0.2, green: 0.5, blue: 0.9)
        case .purple:
            return Color(red: 0.6, green: 0.3, blue: 0.9)
        case .orange:
            return Color(red: 0.9, green: 0.5, blue: 0.15)
        case .pink:
            return Color(red: 0.9, green: 0.3, blue: 0.5)
        case .teal:
            return Color(red: 0.15, green: 0.6, blue: 0.7)
        }
    }
    
    /// Ottiene il colore principale chiaro
    var primaryColorLight: Color {
        switch accentColor {
        case .natural:
            return Color.primary
        case .green:
            return Color(red: 0.3, green: 0.9, blue: 0.5)
        case .blue:
            return Color(red: 0.4, green: 0.7, blue: 1.0)
        case .purple:
            return Color(red: 0.8, green: 0.5, blue: 1.0)
        case .orange:
            return Color(red: 1.0, green: 0.7, blue: 0.3)
        case .pink:
            return Color(red: 1.0, green: 0.5, blue: 0.7)
        case .teal:
            return Color(red: 0.3, green: 0.8, blue: 0.9)
        }
    }
    
    /// Ottiene il gradiente principale
    var primaryGradient: LinearGradient {
        return LinearGradient(
            colors: [primaryColor, primaryColorDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Colore per icone in stile Naturale (semantico); altrimenti primaryColor.
    func semanticIconColor(for context: SemanticIconContext) -> Color {
        guard isNaturalStyle else { return primaryColor }
        switch context {
        case .tagGlutenFree:
            return Color(red: 0.85, green: 0.55, blue: 0.2)
        case .tagBio:
            return Color(red: 0.2, green: 0.7, blue: 0.35)
        case .category(let cat):
            switch cat {
            case .fridge: return Color(red: 0.3, green: 0.5, blue: 1.0)
            case .freezer: return Color(red: 0.3, green: 0.7, blue: 0.9)
            case .pantry: return Color(red: 1.0, green: 0.6, blue: 0.2)
            }
        case .foodType(let type):
            return naturalColor(for: type)
        case .settingsRing:
            return Color(red: 0.25, green: 0.5, blue: 0.9)
        case .settingsAlerts:
            return Color(red: 1.0, green: 0.5, blue: 0.2)
        case .settingsCalendar:
            return Color(red: 0.3, green: 0.55, blue: 0.95)
        case .settingsExpirationInput:
            return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .settingsSuggestions:
            return Color(red: 0.6, green: 0.35, blue: 0.9)
        case .settingsAvailable:
            return Color(red: 0.2, green: 0.7, blue: 0.35)
        case .settingsGear:
            return Color(red: 0.4, green: 0.45, blue: 0.5)
        case .settingsAppearance:
            return Color(red: 0.7, green: 0.4, blue: 0.9)
        case .settingsCloud:
            return Color(red: 0.35, green: 0.6, blue: 0.95)
        case .settingsBackup:
            return Color(red: 0.95, green: 0.6, blue: 0.2)
        case .settingsInfo:
            return Color(red: 0.4, green: 0.5, blue: 0.6)
        case .settingsReset:
            return Color(red: 0.9, green: 0.35, blue: 0.3)
        }
    }
    
    private func naturalColor(for foodType: FoodType) -> Color {
        switch foodType.rawValue {
        case "Frutta": return Color(red: 0.9, green: 0.25, blue: 0.2)
        case "Verdura", "Patate", "Legumi", "Spezie ed erbe", "Frutta secca e semi": return Color(red: 0.95, green: 0.55, blue: 0.15)
        case "Carne", "Pollame", "Salumi": return Color(red: 0.8, green: 0.2, blue: 0.2)
        case "Pesce", "Frutti di mare": return Color(red: 0.25, green: 0.5, blue: 0.9)
        case "Latte", "Yogurt", "Formaggi", "Burro e margarina": return Color(red: 0.95, green: 0.85, blue: 0.4)
        case "Bevande", "Bevande alcoliche": return Color(red: 0.4, green: 0.6, blue: 0.95)
        case "Conserve", "Surgelati": return Color(red: 0.4, green: 0.65, blue: 0.9)
        default: return Color(red: 0.4, green: 0.4, blue: 0.45)
        }
    }
    
    func accentColorForItem(_ item: Any) -> Color {
        return primaryColor
    }
}

