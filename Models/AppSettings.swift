import Foundation
import SwiftData
import SwiftUI

@Model
final class AppSettings {
    var id: UUID = UUID()
    var notificationsEnabled: Bool = true
    var notificationDaysBefore: Int = 1 // 1 = 1 day before, 2 = 2 days before, -1 = custom
    var customNotificationDays: Int = 3 // Numero di giorni custom (solo se notificationDaysBefore == -1)
    var iCloudSyncEnabled: Bool = false
    var smartSuggestionsEnabled: Bool = true
    var hasChosenCloudUsage: Bool = false // Indica se l'utente ha fatto una scelta esplicita su iCloud
    
    // Aspetto
    var appearanceModeRaw: String = AppearanceMode.system.rawValue // AppearanceMode.rawValue
    var animationsEnabled: Bool = true
    var accentColorRaw: String = AccentColor.natural.rawValue
    var progressRingModeRaw: String = ProgressRingMode.safeItems.rawValue // ProgressRingMode.rawValue
    var homeSummaryStyleRaw: String = HomeSummaryStyle.ring.rawValue     // ring = anello, compact = solo riepilogo
    var expirationInputMethodRaw: String = ExpirationInputMethod.calendar.rawValue
    var shoppingListTabEnabled: Bool = false // Voce "Lista della spesa" in tab bar (off di default)
    /// Beta: OCR per leggere la data di scadenza dalla fotocamera (solo la data, esclude il resto)
    var ocrExpirationEnabled: Bool = false
    
    var appearanceMode: AppearanceMode {
        get {
            AppearanceMode(rawValue: appearanceModeRaw) ?? .system
        }
        set {
            appearanceModeRaw = newValue.rawValue
        }
    }
    
    var accentColor: AccentColor {
        get {
            if accentColorRaw == "default" { return .orange }
            return AccentColor(rawValue: accentColorRaw) ?? .natural
        }
        set {
            accentColorRaw = newValue.rawValue
        }
    }
    
    var progressRingMode: ProgressRingMode {
        get {
            ProgressRingMode(rawValue: progressRingModeRaw) ?? .safeItems
        }
        set {
            progressRingModeRaw = newValue.rawValue
        }
    }
    
    var homeSummaryStyle: HomeSummaryStyle {
        get {
            HomeSummaryStyle(rawValue: homeSummaryStyleRaw) ?? .ring
        }
        set {
            homeSummaryStyleRaw = newValue.rawValue
        }
    }
    
    var expirationInputMethod: ExpirationInputMethod {
        get {
            ExpirationInputMethod(rawValue: expirationInputMethodRaw) ?? .calendar
        }
        set {
            expirationInputMethodRaw = newValue.rawValue
        }
    }
    
    init(
        id: UUID = UUID(),
        notificationsEnabled: Bool = true,
        notificationDaysBefore: Int = 1,
        customNotificationDays: Int = 3,
        iCloudSyncEnabled: Bool = false,
        smartSuggestionsEnabled: Bool = true,
        appearanceMode: AppearanceMode = .system,
        animationsEnabled: Bool = true,
        accentColor: AccentColor = .natural,
        progressRingMode: ProgressRingMode = .safeItems,
        homeSummaryStyle: HomeSummaryStyle = .ring,
        expirationInputMethod: ExpirationInputMethod = .calendar,
        hasChosenCloudUsage: Bool = false,
        shoppingListTabEnabled: Bool = false,
        ocrExpirationEnabled: Bool = false
    ) {
        self.id = id
        self.notificationsEnabled = notificationsEnabled
        self.notificationDaysBefore = notificationDaysBefore
        self.customNotificationDays = customNotificationDays
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.smartSuggestionsEnabled = smartSuggestionsEnabled
        self.appearanceModeRaw = appearanceMode.rawValue
        self.animationsEnabled = animationsEnabled
        self.accentColorRaw = accentColor.rawValue
        self.progressRingModeRaw = progressRingMode.rawValue
        self.homeSummaryStyleRaw = homeSummaryStyle.rawValue
        self.expirationInputMethodRaw = expirationInputMethod.rawValue
        self.hasChosenCloudUsage = hasChosenCloudUsage
        self.shoppingListTabEnabled = shoppingListTabEnabled
        self.ocrExpirationEnabled = ocrExpirationEnabled
    }
    
    
    static func defaultSettings() -> AppSettings {
        AppSettings()
    }
    
    /// Restituisce il numero effettivo di giorni prima per le notifiche
    var effectiveNotificationDays: Int {
        if notificationDaysBefore == -1 {
            return customNotificationDays
        }
        return notificationDaysBefore
    }
}

