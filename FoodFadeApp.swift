import SwiftUI
import SwiftData
import UIKit

@main
struct FoodFadeApp: App {
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
                .modelContainer(modelContainer)
        }
    }
    
    /// Carica le impostazioni del tema da UserDefaults o SwiftData
    private func loadThemeSettings() {
        // Prova a caricare dal ModelContainer se disponibile
        // Nota: questo è un fallback, il caricamento completo avviene in ContentView.onAppear
        // Per ora, carichiamo solo le impostazioni di base per evitare problemi di timing
        
        // Aggiorniamo la tab bar e navigation bar con il colore corrente
        DispatchQueue.main.async {
            let primaryUIColor = UIColor(ThemeManager.shared.primaryColor)
            UITabBar.appearance().tintColor = primaryUIColor
            UINavigationBar.appearance().tintColor = primaryUIColor
            UINavigationBar.appearance().largeTitleTextAttributes = [
                .foregroundColor: primaryUIColor
            ]
            UINavigationBar.appearance().titleTextAttributes = [
                .foregroundColor: primaryUIColor
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
                ShoppingItem.self
            ])
            
            // Leggi la scelta dell'utente da UserDefaults
            // Se l'utente non ha ancora fatto la scelta, usa localOnly (default)
            let useiCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
            let hasChosen = UserDefaults.standard.bool(forKey: "hasChosenCloudUsage")
            
            // Determina la configurazione CloudKit
            // IMPORTANTE: CloudKit ha due ambienti separati:
            // - Development: usato quando l'app è in debug/development
            // - Production: usato quando l'app è in release/production
            // I dati NON si sincronizzano tra i due ambienti!
            // Se crei dati in development, non li vedrai in production e viceversa.
            // Per testare la sincronizzazione tra dispositivi, usa una build Release/Production.
            let cloudKitConfig: ModelConfiguration.CloudKitDatabase
            if hasChosen && useiCloud {
                cloudKitConfig = .automatic  // Abilita sincronizzazione iCloud (usa l'ambiente corretto automaticamente)
            } else {
                cloudKitConfig = .none  // Solo locale
            }
            
            // Configurazione del container
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: false,
                cloudKitDatabase: cloudKitConfig
            )
            
            let container = try ModelContainer(for: schema, configurations: [configuration])
            
            // Se iCloud è abilitato, configura il listener per le modifiche remote
            if hasChosen && useiCloud {
                print("☁️ FoodFadeApp: CloudKit abilitato - sincronizzazione automatica attiva")
                print("☁️ FoodFadeApp: Le modifiche ai FoodItem verranno sincronizzate automaticamente con iCloud")
            } else {
                print("📱 FoodFadeApp: CloudKit disabilitato - solo storage locale")
            }
            
            // Inizializza le impostazioni di default se necessario (dopo la creazione del container)
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
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)
            
            InventoryView(filterStatus: nil)
                .tabItem {
                    Label("Inventario", systemImage: "cabinet")
                }
                .tag(1)
            
            ShoppingListView()
                .tabItem {
                    Label("Lista spesa", systemImage: "cart.fill")
                }
                .tag(2)
            
            StatisticsView()
                .tabItem {
                    Label("Statistiche", systemImage: "chart.bar.fill")
                }
                .tag(3)
            
            // Ricette temporaneamente nascosta (instabile)
            // RecipesView()
            //     .tabItem { Label("Ricette", systemImage: "book.fill") }
            //     .tag(4)
            
            SettingsView()
                .tabItem {
                    Label("Impostazioni", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .tint(themeManager.primaryColor)
        .preferredColorScheme(preferredColorScheme)
        .accentColor(themeManager.primaryColor)
        .onAppear {
            loadThemeSettings()
            updateTabBarColor()
        }
        .onChange(of: themeManager.accentColor) { oldValue, newValue in
            updateTabBarColor()
        }
        .onChange(of: themeManager.appearanceMode) { oldValue, newValue in
            // Il preferredColorScheme viene calcolato dinamicamente tramite la computed property
            // Non serve .id() perché preferredColorScheme è reattivo
        }
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
            let primaryUIColor = UIColor(themeManager.primaryColor)
            
            // Tab bar
            UITabBar.appearance().tintColor = primaryUIColor
            
            // Navigation bar - tint per i pulsanti
            UINavigationBar.appearance().tintColor = primaryUIColor
            
            // Navigation bar - titoli (sia large che inline)
            UINavigationBar.appearance().largeTitleTextAttributes = [
                .foregroundColor: primaryUIColor
            ]
            UINavigationBar.appearance().titleTextAttributes = [
                .foregroundColor: primaryUIColor
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

#Preview {
    ContentView()
        .modelContainer(for: [FoodItem.self, AppSettings.self, UserProfile.self], inMemory: true)
}

