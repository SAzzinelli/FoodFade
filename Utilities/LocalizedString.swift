import Foundation

/// Helper per le stringhe localizzate
extension String {
    /// Ritorna la stringa localizzata
    var localized: String {
        // Usa NSLocalizedString standard - iOS gestisce automaticamente la localizzazione
        // se i file .strings sono correttamente configurati nel progetto
        return NSLocalizedString(self, comment: "")
    }
    
    /// Ritorna la stringa localizzata con argomenti
    func localized(_ arguments: CVarArg...) -> String {
        String(format: self.localized, arguments: arguments)
    }
}

