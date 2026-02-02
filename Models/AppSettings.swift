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
    var accentColorRaw: String = AccentColor.default.rawValue // AccentColor.rawValue
    var progressRingModeRaw: String = ProgressRingMode.safeItems.rawValue // ProgressRingMode.rawValue
    
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
            AccentColor(rawValue: accentColorRaw) ?? .default
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
    
    init(
        id: UUID = UUID(),
        notificationsEnabled: Bool = true,
        notificationDaysBefore: Int = 1,
        customNotificationDays: Int = 3,
        iCloudSyncEnabled: Bool = false, // Default false: l'utente deve scegliere esplicitamente
        smartSuggestionsEnabled: Bool = true,
        appearanceMode: AppearanceMode = .system,
        animationsEnabled: Bool = true,
        accentColor: AccentColor = .default,
        progressRingMode: ProgressRingMode = .safeItems,
        hasChosenCloudUsage: Bool = false
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
        self.hasChosenCloudUsage = hasChosenCloudUsage
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

