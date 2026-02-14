import SwiftUI
import SwiftData
import UIKit
import CoreData

@main
struct FoodFadeApp: App {
    @UIApplicationDelegateAdaptor(NotificationDelegate.self) private var notificationDelegate

    init() {
        // Carica le impostazioni del tema all'avvio
        loadThemeSettings()
        
        // Inizializza e verifica disponibilità Apple Intelligence
        Task { @MainActor in
            IntelligenceManager.shared.checkAppleIntelligenceAvailability()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            WelcomeView()
                .environmentObject(NotificationService.shared)
                .modelContainer(modelContainer)
                .onAppear {
                    AppIconManager.applySavedIconIfNeeded()
                }
        }
    }
    
    /// Carica le impostazioni del tema da UserDefaults o SwiftData
    private func loadThemeSettings() {
        // Prova a caricare dal ModelContainer se disponibile
        // Nota: questo è un fallback, il caricamento completo avviene in ContentView.onAppear
        // Per ora, carichiamo solo le impostazioni di base per evitare problemi di timing
        
        // Aggiorniamo la tab bar e navigation bar con il colore corrente
        DispatchQueue.main.async {
            let primaryUIColor: UIColor = ThemeManager.shared.isNaturalStyle
                ? .label  // in Naturale adattivo: nero in light, bianco in dark
                : UIColor(ThemeManager.shared.primaryColor)
            UITabBar.appearance().tintColor = primaryUIColor
            UINavigationBar.appearance().tintColor = primaryUIColor
            // Titoli large e inline in nero (primary solo per pulsanti)
            UINavigationBar.appearance().largeTitleTextAttributes = [
                .foregroundColor: UIColor.label
            ]
            UINavigationBar.appearance().titleTextAttributes = [
                .foregroundColor: UIColor.label
            ]
        }
    }
    
    /// Configurazione del ModelContainer con supporto iCloud
    private var modelContainer: ModelContainer {
        do {
            let schema = Schema([
                FoodItem.self,
                AppSettings.self,
                UserProfile.self,
                CustomFoodType.self,
                ShoppingList.self,
                ShoppingItem.self
            ])
            
            // Leggi la scelta dell'utente da UserDefaults
            let useiCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
            let hasChosen = UserDefaults.standard.bool(forKey: "hasChosenCloudUsage")
            
            // Determina la configurazione CloudKit
            // - Se l'utente NON ha ancora scelto (prima apertura o dopo reinstall): usa CloudKit
            //   così i dati su iCloud possono sincronizzarsi subito dopo reinstall.
            // - Se ha scelto iCloud: usa CloudKit.
            // - Se ha scelto "solo dispositivo": solo locale.
            // IMPORTANTE: Development vs Production sono ambienti separati; per test tra dispositivi usa build Release.
            let cloudKitConfig: ModelConfiguration.CloudKitDatabase
            if !hasChosen || useiCloud {
                cloudKitConfig = .automatic  // Abilita iCloud (prima scelta o utente ha scelto iCloud)
            } else {
                cloudKitConfig = .none  // Solo locale (utente ha scelto "solo su questo iPhone")
            }
            
            // Diagnostica iCloud (per capire dove muore: reinstall → primo avvio → cosa stampa? dopo 10–20 s arrivano remote changes?)
            let iCloudAvailable = FileManager.default.ubiquityIdentityToken != nil
            print("☁️ hasChosen:", hasChosen)
            print("☁️ iCloudSyncEnabled:", useiCloud)
            print("☁️ cloudKitConfig:", cloudKitConfig)
            print("☁️ iCloud available (ubiquityIdentityToken):", iCloudAvailable)
            
            // Configurazione del container
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: cloudKitConfig
            )
            
            let container = try ModelContainer(for: schema, configurations: [configuration])
            
            // Observer per debug: se non vedi questo log → CloudKit non sta parlando
            if !hasChosen || useiCloud {
                NotificationCenter.default.addObserver(
                    forName: .NSPersistentStoreRemoteChange,
                    object: nil,
                    queue: .main
                ) { _ in
                    print("📡 CloudKit ha mandato un update (NSPersistentStoreRemoteChange)")
                }
            }
            
            // Messaggio coerente con cloudKitConfig: .automatic se !hasChosen || useiCloud
            if !hasChosen || useiCloud {
                print("☁️ FoodFadeApp: Container con CloudKit (.automatic) - sincronizzazione attiva")
                if !hasChosen {
                    print("☁️ FoodFadeApp: Primo avvio/reinstall: UserDefaults non ancora impostati, i dati iCloud possono arrivare in seguito")
                }
            } else {
                print("📱 FoodFadeApp: CloudKit disabilitato - solo storage locale (utente ha scelto «solo su questo iPhone»)")
            }
            
            // Inizializza le impostazioni di default se necessario (dopo la creazione del container)
            // ATTENZIONE: con .automatic, creare AppSettings subito può sovrascrivere prima del merge CloudKit.
            // Se dopo reinstall "non ripristina", provare a ritardare questo bootstrap o aspettare un remote change.
            let context = container.mainContext
            let descriptor = FetchDescriptor<AppSettings>()
            
            if (try? context.fetch(descriptor).first) == nil {
                let defaultSettings = AppSettings.defaultSettings()
                context.insert(defaultSettings)
                try? context.save()
            } else {
                // Sincronizza UserDefaults con AppSettings se necessario
                if let settings = try? context.fetch(descriptor).first {
                    if settings.hasChosenCloudUsage {
                        UserDefaults.standard.set(settings.iCloudSyncEnabled, forKey: "iCloudSyncEnabled")
                        UserDefaults.standard.set(true, forKey: "hasChosenCloudUsage")
                    }
                }
            }
            
            return container
        } catch {
            // Per debug, stampa l'errore dettagliato
            print("Errore nella configurazione del ModelContainer: \(error)")
            // Fallback: prova senza iCloud
            do {
                let fallbackSchema = Schema([
                    FoodItem.self,
                    AppSettings.self,
                    UserProfile.self,
                    CustomFoodType.self,
                    ShoppingList.self,
                    ShoppingItem.self
                ])
                let fallbackConfig = ModelConfiguration(
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .none  // Disabilita iCloud come fallback
                )
                return try ModelContainer(for: fallbackSchema, configurations: [fallbackConfig])
            } catch {
                // Ultimo tentativo: database in memoria (per testing)
                do {
                    let inMemorySchema = Schema([
                        FoodItem.self,
                        AppSettings.self,
                        UserProfile.self,
                        CustomFoodType.self,
                        ShoppingList.self,
                        ShoppingItem.self
                    ])
                    let inMemoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                    return try ModelContainer(for: inMemorySchema, configurations: [inMemoryConfig])
                } catch {
                    fatalError("Errore critico nella configurazione del ModelContainer: \(error)")
                }
            }
        }
    }
}

/// Vista principale con TabView
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var trophyUnlockedBannerName: String? = nil
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var notificationService: NotificationService
    @StateObject private var themeManager = ThemeManager.shared
    @Query private var settings: [AppSettings]
    @Query private var allItems: [FoodItem]

    private var shoppingListTabEnabled: Bool {
        settings.first?.shoppingListTabEnabled ?? false
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("nav.home", systemImage: "leaf.fill")
                }
                .tag(0)
            
            InventoryView(filterStatus: nil)
                .tabItem {
                    Label("nav.inventory", systemImage: "cabinet")
                }
                .tag(1)
            
            if shoppingListTabEnabled {
                ShoppingListView()
                    .tabItem {
                        Label("shopping.title", systemImage: "cart.fill")
                    }
                    .tag(2)
            }
            
            StatisticsView()
                .tabItem {
                    Label("nav.statistics", systemImage: "chart.pie.fill")
                }
                .tag(shoppingListTabEnabled ? 3 : 2)
            
            SettingsView()
                .tabItem {
                    Label("nav.settings", systemImage: "slider.horizontal.3")
                }
                .tag(shoppingListTabEnabled ? 4 : 3)
        }
        .onChange(of: shoppingListTabEnabled) { oldValue, newValue in
            if newValue {
                // Abilitando: Statistics era 2 → diventa 3, Impostazioni era 3 → diventa 4
                if selectedTab == 2 { selectedTab = 3 }
                else if selectedTab == 3 { selectedTab = 4 }
            } else {
                if selectedTab == 2 { selectedTab = 0 }
                else if selectedTab == 3 { selectedTab = 2 }
                else if selectedTab == 4 { selectedTab = 3 }
            }
        }
        .tint(themeManager.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : themeManager.primaryColor)
        .preferredColorScheme(preferredColorScheme)
        .accentColor(themeManager.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : themeManager.primaryColor)
        .onAppear {
            loadThemeSettings()
            updateTabBarColor()
            // Rischedula notifiche una sola volta all'avvio (non a ogni visita alla Home)
            if settings.first?.notificationsEnabled == true {
                let days = settings.first?.effectiveNotificationDays ?? 1
                Task {
                    await notificationService.rescheduleNotificationsForItems(allItems, daysBefore: days)
                }
            }
        }
        .onChange(of: themeManager.accentColor) { oldValue, newValue in
            updateTabBarColor()
        }
        .onChange(of: themeManager.appearanceMode) { oldValue, newValue in
            // Il preferredColorScheme viene calcolato dinamicamente tramite la computed property
            // Non serve .id() perché preferredColorScheme è reattivo
        }
        .onChange(of: notificationService.itemIdToOpenFromNotification) { _, id in
            if id != nil { selectedTab = 0 }
        }
        .onChange(of: notificationService.itemIdToMarkAsConsumedFromNotification) { _, id in
            guard let id = id else { return }
            let predicate = #Predicate<FoodItem> { $0.id == id }
            var descriptor = FetchDescriptor<FoodItem>(predicate: predicate)
            descriptor.fetchLimit = 1
            if let item = try? modelContext.fetch(descriptor).first {
                item.isConsumed = true
                item.consumedDate = Date()
                try? modelContext.save()
            }
            notificationService.itemIdToMarkAsConsumedFromNotification = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .trophyUnlocked)) { notification in
            guard let raw = notification.userInfo?["trophyRawValue"] as? String,
                  let trophy = Trophy(rawValue: raw) else { return }
            trophyUnlockedBannerName = trophy.displayName
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                trophyUnlockedBannerName = nil
            }
        }
        .overlay(alignment: .top) {
            if let name = trophyUnlockedBannerName {
                TrophyUnlockedBanner(trophyName: name)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: trophyUnlockedBannerName != nil)
    }
    
    /// Carica le impostazioni del tema dal database
    private func loadThemeSettings() {
        let descriptor = FetchDescriptor<AppSettings>()
        
        if let settings = try? modelContext.fetch(descriptor).first {
            themeManager.appearanceMode = settings.appearanceMode
            themeManager.animationsEnabled = settings.animationsEnabled
            themeManager.accentColor = settings.accentColor
        }
        
        // Aggiorna anche la tab bar e navigation bar
        updateTabBarColor()
    }
    
    private func updateTabBarColor() {
        DispatchQueue.main.async {
            // In modalità Naturale: colore adattivo (nero in light, bianco in dark) per tab e navbar
            let activeUIColor: UIColor = themeManager.isNaturalStyle
                ? .label
                : UIColor(themeManager.primaryColor)
            
            // Tab bar (tab selezionata e elementi attivi)
            UITabBar.appearance().tintColor = activeUIColor
            
            // Navigation bar - tint per pulsanti
            UINavigationBar.appearance().tintColor = activeUIColor
            UINavigationBar.appearance().largeTitleTextAttributes = [
                .foregroundColor: UIColor.label
            ]
            UINavigationBar.appearance().titleTextAttributes = [
                .foregroundColor: UIColor.label
            ]
            
            // Forza il refresh di tutte le navigation bar esistenti
            NotificationCenter.default.post(name: NSNotification.Name("ThemeDidChange"), object: nil)
        }
    }
    
    private var preferredColorScheme: ColorScheme? {
        switch themeManager.appearanceMode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

/// Banner in-app per trofeo appena sbloccato
private struct TrophyUnlockedBanner: View {
    let trophyName: String
    private var accent: Color {
        ThemeManager.shared.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20))
                .foregroundColor(accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("trophy.banner.title".localized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Text(trophyName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    ContentView()
        .environmentObject(NotificationService.shared)
        .modelContainer(for: [FoodItem.self, AppSettings.self, UserProfile.self, ShoppingList.self, ShoppingItem.self], inMemory: true)
}

