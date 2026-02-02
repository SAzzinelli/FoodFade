import Foundation

/// Helper per gestire il genere nelle stringhe localizzate
/// Usa un enum compatibile con le varianti di genere nelle stringhe localizzate
enum GenderHelper {
    /// Genere dell'utente
    enum Gender: String, CaseIterable {
        case masculine = "masculine"
        case feminine = "feminine"
        case neutral = "neutral"
    }
    
    /// Ottiene il genere dal profilo utente
    static func getGender(from profile: UserProfile?) -> Gender {
        // Se il profilo ha un genere esplicito salvato, usalo
        if let profile = profile, let genderRaw = profile.termOfAddressRaw,
           let gender = Gender(rawValue: genderRaw) {
            return gender
        }
        
        // Altrimenti usa neutro come default
        return .neutral
    }
    
    /// Ottiene una stringa localizzata con variante di genere
    /// Formato chiavi: "key.masculine", "key.feminine", "key.neutral", "key" (fallback)
    static func localizedString(
        _ key: String,
        gender: Gender,
        comment: String = ""
    ) -> String {
        // Prova prima la variante di genere
        let genderKey = "\(key).\(gender.rawValue)"
        let genderedString = NSLocalizedString(genderKey, comment: comment)
        
        // Se la variante di genere esiste (non è uguale alla chiave), usala
        // NSLocalizedString restituisce la chiave stessa se non trova la traduzione
        if genderedString != genderKey {
            return genderedString
        }
        
        // Fallback alla chiave base
        let baseString = NSLocalizedString(key, comment: comment)
        
        // Se anche la chiave base non è stata trovata, potrebbe essere un problema con il bundle
        // In questo caso, proviamo a usare Bundle.main esplicitamente
        if baseString == key {
            if let bundle = Bundle.main.path(forResource: "Localizable", ofType: "strings", inDirectory: "it.lproj"),
               let dict = NSDictionary(contentsOfFile: bundle),
               let value = dict[key] as? String {
                return value
            }
        }
        
        return baseString
    }
    
    /// Ottiene una stringa localizzata con formato e variante di genere
    static func localizedString(
        _ key: String,
        gender: Gender,
        arguments: CVarArg...,
        comment: String = ""
    ) -> String {
        let baseString = localizedString(key, gender: gender, comment: comment)
        return String(format: baseString, arguments: arguments)
    }
    
    /// Helper per ottenere la stringa localizzata direttamente dal profilo
    static func localizedString(
        _ key: String,
        from profile: UserProfile?,
        comment: String = ""
    ) -> String {
        let gender = getGender(from: profile)
        return localizedString(key, gender: gender, comment: comment)
    }
}
