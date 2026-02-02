import SwiftUI
import Combine

/// Manager per il tema dell'app con supporto per colori personalizzati
@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var accentColor: AccentColor = .default
    @Published var animationsEnabled: Bool = true
    @Published var appearanceMode: AppearanceMode = .system
    
    private init() {}
    
    /// Ottiene il colore principale basato sulla selezione
    var primaryColor: Color {
        switch accentColor {
        case .default:
            return Color(red: 1.0, green: 0.6, blue: 0.2) // Arancione come default
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
        case .default:
            return Color(red: 0.9, green: 0.5, blue: 0.15) // Arancione scuro come default
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
        case .default:
            return Color(red: 1.0, green: 0.7, blue: 0.3) // Arancione chiaro come default
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
    
    /// Ottiene il colore d'accento per un elemento specifico (solo se default, altrimenti usa primaryColor)
    func accentColorForItem(_ item: Any) -> Color {
        return primaryColor
    }
}

