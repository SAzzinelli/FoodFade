import SwiftUI

/// Sistema di colori e tema dell'app
struct AppTheme {
    // Colori principali
    static let primaryGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let primaryGreenDark = Color(red: 0.15, green: 0.7, blue: 0.35)
    static let primaryGreenLight = Color(red: 0.3, green: 0.9, blue: 0.5)
    
    // Accenti
    static let accentOrange = Color(red: 1.0, green: 0.6, blue: 0.2)
    static let accentYellow = Color(red: 1.0, green: 0.85, blue: 0.3)
    static let accentRed = Color(red: 1.0, green: 0.35, blue: 0.35)
    static let accentBlue = Color(red: 0.3, green: 0.6, blue: 1.0)
    static let accentPurple = Color(red: 0.7, green: 0.4, blue: 1.0)
    
    // Sfondo
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.98, green: 0.99, blue: 1.0),
            Color(red: 0.95, green: 0.98, blue: 0.97)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardBackground = Color.white
    static let cardShadow = Color.black.opacity(0.08)
    
    // Testo
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color.secondary.opacity(0.7)
    
    // Colore singolo per categoria (usato in liste e filtri)
    static func color(for category: FoodCategory) -> Color {
        switch category {
        case .fridge: return .blue
        case .freezer: return .cyan
        case .pantry: return .orange
        }
    }
    
    // Gradazioni per categorie
    static func gradient(for category: FoodCategory) -> LinearGradient {
        switch category {
        case .fridge:
            return LinearGradient(
                colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .freezer:
            return LinearGradient(
                colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .pantry:
            return LinearGradient(
                colors: [Color.orange.opacity(0.8), Color(red: 1.0, green: 0.7, blue: 0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    // Gradazione per stato scadenza
    static func gradient(for status: ExpirationStatus) -> LinearGradient {
        switch status {
        case .expired:
            return LinearGradient(
                colors: [accentRed, Color.red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .today:
            return LinearGradient(
                colors: [accentOrange, Color.orange.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .soon:
            return LinearGradient(
                colors: [accentOrange, Color.orange.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .safe:
            return LinearGradient(
                colors: [primaryGreen, primaryGreenDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

/// Stili per il testo
extension Text {
    func appTitle() -> some View {
        self
            .font(.system(size: 42, weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.textPrimary)
    }
    
    func appHeadline() -> some View {
        self
            .font(.system(size: 24, weight: .semibold, design: .rounded))
            .foregroundStyle(AppTheme.textPrimary)
    }
    
    func appSubheadline() -> some View {
        self
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(AppTheme.textSecondary)
    }
    
    func appBody() -> some View {
        self
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundStyle(AppTheme.textPrimary)
    }
}

