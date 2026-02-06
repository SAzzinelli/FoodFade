import Foundation
import SwiftData
import SwiftUI
import Combine
import CloudKit

/// Deve coincidere con l'identificatore in FoodFade.entitlements e in Xcode (Capabilities → iCloud → Containers).
private let kCloudKitContainerID = "iCloud.com.food.fade.FoodFade"

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var notificationsEnabled: Bool = true
    @Published var notificationDaysBefore: Int = 1 // 1, 2, o -1 per custom
    @Published var customNotificationDays: Int = 3
    @Published var smartSuggestionsEnabled: Bool = true
    @Published var intelligenceEnabled: Bool = true
    @Published var iCloudStatus: String = "Attiva"
    
    // Aspetto
    @Published var appearanceMode: AppearanceMode = .system
    @Published var animationsEnabled: Bool = true
    @Published var accentColor: AccentColor = .natural
    @Published var progressRingMode: ProgressRingMode = .safeItems
    @Published var expirationInputMethod: ExpirationInputMethod = .calendar
    
    private var modelContext: ModelContext?
    private let notificationService = NotificationService.shared
    private let intelligenceService = AppleIntelligenceService.shared
    private let intelligenceManager = IntelligenceManager.shared
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSettings()
        checkiCloudStatus()
        // Verifica disponibilità Apple Intelligence
        intelligenceManager.checkAppleIntelligenceAvailability()
        // Sincronizza stato
        intelligenceEnabled = intelligenceManager.isEnabled
    }
    
    private func loadSettings() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<AppSettings>()
        
        if let settings = try? modelContext.fetch(descriptor).first {
            notificationsEnabled = settings.notificationsEnabled
            notificationDaysBefore = settings.notificationDaysBefore
            customNotificationDays = settings.customNotificationDays
            smartSuggestionsEnabled = settings.smartSuggestionsEnabled
            // Sincronizza con IntelligenceManager
            IntelligenceManager.shared.checkAppleIntelligenceAvailability()
            intelligenceEnabled = IntelligenceManager.shared.isEnabled
            appearanceMode = settings.appearanceMode
            animationsEnabled = settings.animationsEnabled
            accentColor = settings.accentColor
            progressRingMode = settings.progressRingMode
            expirationInputMethod = settings.expirationInputMethod
            
            // Aggiorna ThemeManager
            ThemeManager.shared.appearanceMode = appearanceMode
            ThemeManager.shared.animationsEnabled = animationsEnabled
            ThemeManager.shared.accentColor = accentColor
            
            // Sincronizza IntelligenceManager
            IntelligenceManager.shared.isEnabled = intelligenceEnabled
        } else {
            // Crea impostazioni di default
            let defaultSettings = AppSettings.defaultSettings()
            modelContext.insert(defaultSettings)
            try? modelContext.save()
        }
    }
    
    func saveSettings() {
        // Aggiorna ThemeManager PRIMA di salvare (per applicazione immediata)
        updateThemeManager()
        
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<AppSettings>()
        
        if let settings = try? modelContext.fetch(descriptor).first {
            settings.notificationsEnabled = notificationsEnabled
            settings.notificationDaysBefore = notificationDaysBefore
            settings.customNotificationDays = customNotificationDays
            settings.smartSuggestionsEnabled = smartSuggestionsEnabled
            settings.appearanceMode = appearanceMode
            settings.animationsEnabled = animationsEnabled
            settings.accentColor = accentColor
            settings.progressRingMode = progressRingMode
            settings.expirationInputMethod = expirationInputMethod
            
            try? modelContext.save()
        } else {
            let newSettings = AppSettings(
                notificationsEnabled: notificationsEnabled,
                notificationDaysBefore: notificationDaysBefore,
                customNotificationDays: customNotificationDays,
                smartSuggestionsEnabled: smartSuggestionsEnabled,
                appearanceMode: appearanceMode,
                animationsEnabled: animationsEnabled,
                accentColor: accentColor,
                progressRingMode: progressRingMode,
                expirationInputMethod: expirationInputMethod
            )
            modelContext.insert(newSettings)
            try? modelContext.save()
        }
        
        // Aggiorna anche la tab bar e navigation bar
        let primaryUIColor = UIColor(ThemeManager.shared.primaryColor)
        UITabBar.appearance().tintColor = primaryUIColor
        UINavigationBar.appearance().tintColor = primaryUIColor
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        UINavigationBar.appearance().titleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
        
        // Richiedi autorizzazioni notifiche se abilitate
        if notificationsEnabled {
            Task {
                try? await notificationService.requestAuthorization()
            }
        }
    }
    
    func checkiCloudStatus() {
        Task {
            let container = CKContainer.default()
            do {
                let status = try await container.accountStatus()
                await MainActor.run {
                    // Controlla anche la scelta dell'utente
                    guard let modelContext = modelContext else { return }
                    let descriptor = FetchDescriptor<AppSettings>()
                    if let settings = try? modelContext.fetch(descriptor).first {
                        if status == .available && settings.iCloudSyncEnabled {
                            self.iCloudStatus = "Attiva"
                        } else if status == .available && !settings.iCloudSyncEnabled {
                            self.iCloudStatus = "Disattivata per scelta dell'utente"
                        } else {
                            self.iCloudStatus = "Non disponibile"
                        }
                    } else {
                        if status == .available {
                            self.iCloudStatus = "Attiva"
                        } else {
                            self.iCloudStatus = "Non disponibile"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.iCloudStatus = "Non disponibile"
                }
            }
        }
    }
    
    var isSmartSuggestionsAvailable: Bool {
        intelligenceService.isAvailable
    }
    
    var isAppleIntelligenceAvailable: Bool {
        intelligenceManager.isAppleIntelligenceAvailable
    }
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    /// Restituisce il numero effettivo di giorni prima per le notifiche
    var effectiveNotificationDays: Int {
        if notificationDaysBefore == -1 {
            return customNotificationDays
        }
        return notificationDaysBefore
    }
    
    private func updateThemeManager() {
        ThemeManager.shared.appearanceMode = appearanceMode
        ThemeManager.shared.animationsEnabled = animationsEnabled
        ThemeManager.shared.accentColor = accentColor
    }
    
    /// Ripristina dati da iCloud (forza sincronizzazione)
    /// 
    /// NOTA IMPORTANTE: Per il ripristino da iCloud funzioni correttamente, assicurati che:
    /// 1. Il tuo Apple Developer Account abbia CloudKit abilitato
    /// 2. L'App ID nel Developer Portal abbia CloudKit capability abilitata
    /// 3. Il Container CloudKit sia configurato correttamente nel progetto Xcode
    /// 4. L'utente abbia iCloud Drive abilitato e sia loggato con il suo Apple ID
    /// 5. Stai usando lo stesso ambiente CloudKit (development o production) su entrambi i dispositivi
    /// 
    /// Con SwiftData + CloudKit, la sincronizzazione è automatica quando:
    /// - Il ModelContainer è configurato con cloudKitDatabase: .automatic
    /// - L'utente ha scelto di usare iCloud durante l'onboarding
    /// - I dispositivi sono collegati allo stesso Apple ID
    /// 
    /// IMPORTANTE: La sincronizzazione CloudKit è ASINCRONA e può richiedere alcuni secondi o minuti.
    /// Questa funzione forza un refresh del context per triggerare la sincronizzazione.
    func restoreFromiCloud() {
        guard let modelContext = modelContext else {
            print("❌ restoreFromiCloud: modelContext non disponibile")
            return
        }
        
        // Verifica che iCloud sia abilitato
        let useiCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        guard useiCloud else {
            print("⚠️ restoreFromiCloud: iCloud non è abilitato nelle impostazioni")
            return
        }
        
        print("🔄 restoreFromiCloud: Inizio sincronizzazione forzata...")
        
        Task {
            // Verifica lo stato di iCloud
            let container = CKContainer(identifier: kCloudKitContainerID)
            do {
                let accountStatus = try await container.accountStatus()
                print("📱 restoreFromiCloud: Account status: \(accountStatus.rawValue)")
                
                guard accountStatus == .available else {
                    print("❌ restoreFromiCloud: Account iCloud non disponibile (status: \(accountStatus.rawValue))")
                    await MainActor.run {
                        // Mostra errore all'utente
                    }
                    return
                }
            } catch {
                print("❌ restoreFromiCloud: Errore verifica account: \(error)")
                return
            }
            
            await MainActor.run {
                // Verifica la configurazione CloudKit
                print("🔍 restoreFromiCloud: Verifica configurazione CloudKit...")
                let useiCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
                let hasChosen = UserDefaults.standard.bool(forKey: "hasChosenCloudUsage")
                print("🔍 restoreFromiCloud: iCloudSyncEnabled=\(useiCloud), hasChosenCloudUsage=\(hasChosen)")
                
                // Forza un fetch per triggerare la sincronizzazione CloudKit
                // SwiftData sincronizza automaticamente in background, ma possiamo forzare un refresh
                let descriptor = FetchDescriptor<FoodItem>(
                    sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                )
                
                do {
                    let items = try modelContext.fetch(descriptor)
                    print("✅ restoreFromiCloud: Trovati \(items.count) FoodItem locali")
                    for (index, item) in items.prefix(5).enumerated() {
                        print("  [\(index)] \(item.name) - ID: \(item.id) - CategoryRaw: \(item.categoryRaw)")
                    }
                    
                    // Forza anche un refresh delle altre entità
                    let settingsDescriptor = FetchDescriptor<AppSettings>()
                    let settings = try? modelContext.fetch(settingsDescriptor)
                    print("✅ restoreFromiCloud: Trovati \(settings?.count ?? 0) AppSettings")
                    
                    let profileDescriptor = FetchDescriptor<UserProfile>()
                    let profiles = try? modelContext.fetch(profileDescriptor)
                    print("✅ restoreFromiCloud: Trovati \(profiles?.count ?? 0) UserProfile")
                    
                    // Forza un save per triggerare la sincronizzazione
                    try? modelContext.save()
                    print("💾 restoreFromiCloud: Save eseguito")
                    
                    // Attendi un po' e rifai il fetch per vedere se arrivano nuovi dati
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 secondi
                        await MainActor.run {
                            let newItems = try? modelContext.fetch(descriptor)
                            print("🔄 restoreFromiCloud: Dopo 3 secondi, trovati \(newItems?.count ?? 0) FoodItem")
                            if let newItems = newItems, newItems.count > items.count {
                                print("✅ restoreFromiCloud: Nuovi FoodItem arrivati da iCloud!")
                                for item in newItems.prefix(5) {
                                    print("  - \(item.name) - ID: \(item.id)")
                                }
                            } else if let newItems = newItems, newItems.count == items.count && items.count > 0 {
                                print("✅ restoreFromiCloud: FoodItem locali presenti (\(items.count)) - sincronizzazione in corso o già completata")
                                print("💡 restoreFromiCloud: I FoodItem locali dovrebbero essere sincronizzati automaticamente con iCloud")
                            } else {
                                print("⚠️ restoreFromiCloud: Nessun nuovo FoodItem da iCloud")
                                print("💡 restoreFromiCloud: Possibili cause:")
                                print("   1. Nessun FoodItem salvato su iCloud da altri dispositivi")
                                print("   2. I dati sono stati salvati in un ambiente CloudKit diverso (Development vs Production)")
                                print("   3. La sincronizzazione richiede più tempo (prova ad attendere qualche minuto)")
                                print("   4. Verifica su developer.apple.com/cloudkit che i dati siano presenti nel Dashboard")
                            }
                            
                            // Haptic feedback
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }
                    }
                } catch {
                    print("❌ restoreFromiCloud: Errore durante il fetch: \(error)")
                }
            }
        }
    }
    
    /// Verifica lo stato di sincronizzazione CloudKit per i FoodItem
    func checkCloudKitSyncStatus() {
        guard let modelContext = modelContext else {
            print("❌ checkCloudKitSyncStatus: modelContext non disponibile")
            return
        }
        
        let useiCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        guard useiCloud else {
            print("⚠️ checkCloudKitSyncStatus: iCloud non è abilitato")
            return
        }
        
        Task {
            let container = CKContainer(identifier: kCloudKitContainerID)
            do {
                let accountStatus = try await container.accountStatus()
                print("☁️ checkCloudKitSyncStatus: Account iCloud status: \(accountStatus.rawValue)")
                
                await MainActor.run {
                    let descriptor = FetchDescriptor<FoodItem>(
                        sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
                    )
                    
                    if let items = try? modelContext.fetch(descriptor) {
                        print("☁️ checkCloudKitSyncStatus: Trovati \(items.count) FoodItem locali")
                        if items.count > 0 {
                            print("☁️ checkCloudKitSyncStatus: FoodItem presenti:")
                            for item in items.prefix(3) {
                                print("  - \(item.name) (ID: \(item.id))")
                            }
                        }
                        print("☁️ checkCloudKitSyncStatus: iCloud sync dovrebbe avvenire automaticamente in background")
                        print("☁️ checkCloudKitSyncStatus: Per verificare se i dati sono su iCloud, usa il Dashboard CloudKit su developer.apple.com")
                    }
                }
            } catch {
                print("❌ checkCloudKitSyncStatus: Errore: \(error)")
            }
        }
    }
}
