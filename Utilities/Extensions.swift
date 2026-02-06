import Foundation
import SwiftUI

// MARK: - Date Extensions
extension Date {
    func days(from date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }
    
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// Formato scadenza breve: "17 MAR 2026" (mesi 3 lettere maiuscole).
    var expirationShortLabel: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "it_IT")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: self).uppercased()
    }
}

// MARK: - Color Extensions
extension Color {
    static let systemBackground = Color(uiColor: .systemBackground)
    static let systemGray5 = Color(uiColor: .systemGray5)
    static let systemGray6 = Color(uiColor: .systemGray6)
}

// MARK: - View Extensions
extension View {
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

