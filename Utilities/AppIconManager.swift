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

        /// Nome dell’asset in Assets.xcassets da usare come anteprima (icona reale).
        /// Asset per l’anteprima in Icona app (allineati a FoodFade_principale, FoodFade_opt1, FoodFade_opt2).
        var previewImageName: String {
            switch self {
            case .primary: return "AppIconPreviewPrimary"
            case .opt1: return "AppIconPreviewOpt1"
            case .opt2: return "AppIconPreviewOpt2"
            }
        }
    }
    
    /// Restituisce l’opzione attualmente salvata.
    static var savedOption: Option {
        let raw = UserDefaults.standard.string(forKey: userDefaultsKey)
        return Option(rawValue: raw ?? Option.primary.rawValue) ?? .primary
    }
    
    /// Salva l’opzione e applica l’icona.
    /// Ritenta fino a 2 volte se iOS restituisce "risorsa non disponibile". Sul Simulator spesso solo opt2 funziona; su device tutte.
    static func setIcon(_ option: Option, completion: ((Bool, Error?) -> Void)? = nil) {
        UserDefaults.standard.set(option.rawValue, forKey: userDefaultsKey)
        guard UIApplication.shared.supportsAlternateIcons else {
            completion?(false, nil)
            return
        }
        performSetIcon(requestedName: option.alternateIconName, retryCount: 2, completion: completion)
    }

    /// Sul Simulator setAlternateIconName spesso fallisce per primary/opt1; su device di solito ok. Ritenta fino a 2 volte con delay 0.6s e 1.2s.
    private static func performSetIcon(requestedName: String?, retryCount: Int, completion: ((Bool, Error?) -> Void)?) {
        UIApplication.shared.setAlternateIconName(requestedName) { error in
            DispatchQueue.main.async {
                let current = UIApplication.shared.alternateIconName
                if current == requestedName {
                    completion?(true, nil)
                    return
                }
                let msg = (error as NSError?)?.localizedDescription.lowercased() ?? ""
                let isUnavailable = msg.contains("non disponibile") || msg.contains("temporarily unavailable")
                if retryCount > 0, isUnavailable {
                    let delay: Double = retryCount == 2 ? 0.6 : 1.2
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        performSetIcon(requestedName: requestedName, retryCount: retryCount - 1, completion: completion)
                    }
                } else {
                    completion?(false, error)
                }
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
