import UIKit

/// Gestione icona app alternate (FoodFade_principale = default, FoodFade_opt1, FoodFade_opt2).
enum AppIconManager {
    static let userDefaultsKey = "AppIconName"
    
    /// Nome icona principale (default) – passare `nil` a `setAlternateIconName` per usarla.
    static let primaryIconName: String? = nil
    
    /// Chiavi per le icona opzionali (devono coincidere con CFBundleAlternateIcons in Info.plist).
    static let opt1Name = "FoodFade_opt1"
    static let opt2Name = "FoodFade_opt2"
    
    /// Opzioni disponibili per l’utente.
    enum Option: String, CaseIterable {
        case primary = "FoodFade_principale"
        case opt1 = "FoodFade_opt1"
        case opt2 = "FoodFade_opt2"
        
        /// Nome da passare a `setAlternateIconName` (nil = icona principale).
        var alternateIconName: String? {
            switch self {
            case .primary: return nil
            case .opt1: return AppIconManager.opt1Name
            case .opt2: return AppIconManager.opt2Name
            }
        }
        
        var displayName: String {
            switch self {
            case .primary: return "settings.app_icon.primary".localized
            case .opt1: return "settings.app_icon.opt1".localized
            case .opt2: return "settings.app_icon.opt2".localized
            }
        }
    }
    
    /// Restituisce l’opzione attualmente salvata.
    static var savedOption: Option {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey)
        return Option(rawValue: raw ?? Option.primary.rawValue) ?? .primary
    }
    
    /// Salva l’opzione e applica l’icona.
    /// In caso di errore, completion riceve (false, error) per mostrare il messaggio di sistema.
    static func setIcon(_ option: Option, completion: ((Bool, Error?) -> Void)? = nil) {
        UserDefaults.standard.set(option.rawValue, forKey: userDefaultsKey)
        guard UIApplication.shared.supportsAlternateIcons else {
            completion?(false, nil)
            return
        }
        UIApplication.shared.setAlternateIconName(option.alternateIconName) { error in
            DispatchQueue.main.async {
                completion?(error == nil, error)
            }
        }
    }
    
    /// Applica l’icona salvata (da chiamare al launch).
    static func applySavedIconIfNeeded() {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let option = savedOption
        let name = option.alternateIconName
        if UIApplication.shared.alternateIconName != name {
            UIApplication.shared.setAlternateIconName(name, completionHandler: nil)
        }
    }
}
