import Foundation
import SwiftData
import Combine
import UIKit

@MainActor
class AddFoodViewModel: ObservableObject {
    @Published var name: String = ""
    @Published var category: FoodCategory = .fridge
    @Published var expirationDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @Published var quantity: Int = 1
    @Published var notes: String = ""
    @Published var notify: Bool = true
    @Published var barcode: String?
    @Published var isScanning: Bool = false
    @Published var isLoadingProduct: Bool = false
    @Published var errorMessage: String?
    @Published var selectedPhoto: UIImage?
    @Published var foodType: FoodType? = nil
    @Published var isGlutenFree: Bool = false
    @Published var isBio: Bool = false
    @Published var isVegan: Bool = false
    @Published var isLactoseFree: Bool = false
    @Published var isVegetarian: Bool = false
    @Published var isReady: Bool = false
    @Published var needsCooking: Bool = false
    @Published var isArtisan: Bool = false
    @Published var isSinglePortion: Bool = false
    @Published var isMultiPortion: Bool = false
    /// Prezzo (opzionale) – testo per campo numerico
    @Published var priceText: String = ""
    
    // Gestione prodotti freschi (semplificata)
    @Published var isFresh: Bool = false { // Prodotto fresco (scade dopo 3 giorni)
        didSet {
            handleFreshModeChange(from: oldValue, to: isFresh)
        }
    }
    
    // Validazione
    @Published var dateValidationError: String? = nil
    
    // Autocompletamento
    @Published var suggestedProducts: [String] = []
    
    private var modelContext: ModelContext?
    private let lookupService = FoodLookupService()
    private let notificationService = NotificationService.shared
    
    var canSave: Bool {
        guard !name.isEmpty else { return false }
        guard quantity >= 1 else { return false }
        
        // Se non è fresco, valida la data
        if !isFresh {
            // Verifica che la data non sia nel passato
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            let startOfExpiration = calendar.startOfDay(for: expirationDate)
            
            if startOfExpiration < startOfToday {
                return false
            }
        }
        
        return true
    }
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        validateDate()
        loadSuggestedProducts()
    }
    
    /// Carica i suggerimenti per l'autocompletamento
    func loadSuggestedProducts() {
        guard let modelContext = modelContext else { return }
        
        let descriptor = FetchDescriptor<FoodItem>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        
        do {
            let allItems = try modelContext.fetch(descriptor)
            // Estrai nomi unici (case-insensitive) e ordina per frequenza
            var nameCounts: [String: Int] = [:]
            for item in allItems {
                let normalizedName = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalizedName.isEmpty {
                    nameCounts[normalizedName, default: 0] += 1
                }
            }
            
            // Ordina per frequenza (più usati prima) e prendi i primi 20
            suggestedProducts = Array(nameCounts.keys.sorted { nameCounts[$0]! > nameCounts[$1]! }.prefix(20))
        } catch {
            print("Errore nel caricamento dei suggerimenti: \(error)")
            suggestedProducts = []
        }
    }
    
    /// Filtra i suggerimenti in base al testo inserito
    func filterSuggestions(for searchText: String) -> [String] {
        guard !searchText.isEmpty else { return [] }
        
        let lowercasedSearch = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowercasedSearch.isEmpty else { return [] }
        
        return suggestedProducts.filter { product in
            product.contains(lowercasedSearch)
        }.prefix(5).map { $0 } // Massimo 5 suggerimenti
    }
    
    /// Gestisce il cambio di modalità prodotto fresco ↔ non fresco
    private func handleFreshModeChange(from oldValue: Bool, to newValue: Bool) {
        let calendar = Calendar.current
        let now = Date()
        
        if newValue {
            // Da Non Fresco → Fresco: scarta la data precedente e imposta now + 3 giorni
            expirationDate = calendar.date(byAdding: .day, value: 3, to: now) ?? expirationDate
            dateValidationError = nil
        } else {
            // Da Fresco → Non Fresco: imposta data di default (now + 30 giorni)
            expirationDate = calendar.date(byAdding: .day, value: 30, to: now) ?? expirationDate
            validateDate()
        }
    }
    
    /// Valida la data di scadenza
    func validateDate() {
        guard !isFresh else {
            dateValidationError = nil
            return
        }
        
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfExpiration = calendar.startOfDay(for: expirationDate)
        
        if startOfExpiration < startOfToday {
            dateValidationError = "La data non può essere nel passato"
        } else {
            dateValidationError = nil
        }
    }
    
    func handleBarcodeScanned(_ barcode: String) {
        #if DEBUG
        print("📱 AddFoodViewModel - Barcode scanned: \(barcode)")
        #endif
        self.barcode = barcode
        Task {
            await lookupProduct(barcode: barcode)
        }
    }
    
    /// Applica un barcode iniziale (es. da scanner in Home) e avvia il lookup
    func applyInitialBarcode(_ barcode: String?) {
        guard let barcode = barcode, !barcode.isEmpty else { return }
        handleBarcodeScanned(barcode)
    }
    
    private func lookupProduct(barcode: String) async {
        print("🔍 AddFoodViewModel - Starting lookup for barcode: \(barcode)")
        isLoadingProduct = true
        errorMessage = nil
        
        do {
            if let productInfo = try await lookupService.lookupProduct(barcode: barcode) {
                print("✅ AddFoodViewModel - Product found: \(productInfo.name)")
                name = productInfo.name
                if let suggestedCategory = productInfo.category {
                    category = suggestedCategory
                    print("✅ AddFoodViewModel - Category set to: \(suggestedCategory)")
                }
                
                // Scarica l'immagine del prodotto se disponibile (in background, non blocca)
                if let imageUrl = productInfo.imageUrl, let url = URL(string: imageUrl) {
                    print("📷 AddFoodViewModel - Downloading image from: \(imageUrl)")
                    await downloadProductImage(from: url)
                    print("✅ AddFoodViewModel - Immagine scaricata e impostata: \(selectedPhoto != nil ? "Sì" : "No")")
                } else {
                    print("⚠️ AddFoodViewModel - No image URL available")
                }
                
                // Aggiungi ingredienti alle note se disponibili
                if let ingredients = productInfo.ingredients, !ingredients.isEmpty {
                    if notes.isEmpty {
                        notes = "Ingredienti: \(ingredients)"
                    } else {
                        notes = "\(notes)\n\nIngredienti: \(ingredients)"
                    }
                    print("✅ AddFoodViewModel - Ingredients added to notes")
                }
            } else {
                print("❌ AddFoodViewModel - Product not found in database")
                // Prodotto non trovato - non è un errore critico, l'utente può inserire manualmente
                errorMessage = nil // Non mostrare errore, solo permettere inserimento manuale
            }
            isLoadingProduct = false
        } catch {
            print("❌ AddFoodViewModel - Error: \(error.localizedDescription)")
            // Errore di rete - non è critico, l'utente può inserire manualmente
            errorMessage = nil
            isLoadingProduct = false
        }
    }
    
    /// Scarica l'immagine del prodotto da Open Food Facts
    private func downloadProductImage(from url: URL) async {
        print("📥 AddFoodViewModel - Inizio download immagine da: \(url.absoluteString)")
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            print("📥 AddFoodViewModel - Dati scaricati: \(data.count) bytes")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("⚠️ AddFoodViewModel - Risposta HTTP non valida")
                return
            }
            
            print("📥 AddFoodViewModel - Status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("⚠️ AddFoodViewModel - Errore HTTP durante il download dell'immagine: \(httpResponse.statusCode)")
                return
            }
            
            if let image = UIImage(data: data) {
                await MainActor.run {
                    selectedPhoto = image
                    print("✅ AddFoodViewModel - Immagine scaricata e impostata con successo. Dimensioni: \(image.size)")
                }
            } else {
                print("⚠️ AddFoodViewModel - Impossibile creare UIImage dai dati scaricati (dati: \(data.count) bytes)")
            }
        } catch {
            print("❌ AddFoodViewModel - Errore durante il download dell'immagine: \(error.localizedDescription)")
        }
    }
    
    func save() async throws {
        guard !name.isEmpty else {
            throw ValidationError.nameRequired
        }
        
        guard let modelContext = modelContext else {
            throw ValidationError.noContext
        }
        
        // Validazione data (solo se non è fresco)
        if !isFresh {
            let calendar = Calendar.current
            let startOfToday = calendar.startOfDay(for: Date())
            let startOfExpiration = calendar.startOfDay(for: expirationDate)
            
            if startOfExpiration < startOfToday {
                throw ValidationError.dateInPast
            }
        }
        
        // Converti l'immagine in Data se presente
        let photoData = selectedPhoto?.jpegData(compressionQuality: 0.8)
        
        // Se è fresco, calcola la data di scadenza (3 giorni dalla creazione)
        let calendar = Calendar.current
        let baseExpirationDate: Date
        if isFresh {
            baseExpirationDate = calendar.date(byAdding: .day, value: 3, to: Date()) ?? expirationDate
        } else {
            baseExpirationDate = expirationDate
        }
        
        let parsedPrice: Double? = {
            let t = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: ",", with: ".")
            guard !t.isEmpty, let v = Double(t), v >= 0 else { return nil }
            return v
        }()
        
        let item = FoodItem(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            expirationDate: baseExpirationDate,
            quantity: quantity,
            notes: notes.isEmpty ? nil : notes,
            barcode: barcode,
            notify: notify,
            photoData: photoData,
            foodType: foodType,
            isGlutenFree: isGlutenFree,
            isBio: isBio,
            isVegan: isVegan,
            isLactoseFree: isLactoseFree,
            isVegetarian: isVegetarian,
            isReady: isReady,
            needsCooking: needsCooking,
            isArtisan: isArtisan,
            isSinglePortion: isSinglePortion,
            isMultiPortion: isMultiPortion,
            isFresh: isFresh,
            isOpened: false,
            openedDate: nil,
            useAdvancedExpiry: false,
            price: parsedPrice
        )
        
        // Verifica configurazione CloudKit
        let useiCloud = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        print("☁️ AddFoodViewModel - iCloud sync abilitato: \(useiCloud)")
        
        modelContext.insert(item)
        print("💾 AddFoodViewModel - FoodItem inserito nel context: \(item.name)")
        
        let itemId = item.id // Salva l'ID prima del save
        try modelContext.save()
        print("✅ AddFoodViewModel - FoodItem salvato con successo. ID: \(itemId), CategoryRaw: \(item.categoryRaw)")
        
        // Verifica che il salvataggio sia andato a buon fine
        let verifyDescriptor = FetchDescriptor<FoodItem>(
            predicate: #Predicate<FoodItem> { item in
                item.id == itemId
            }
        )
        if let savedItem = try? modelContext.fetch(verifyDescriptor).first {
            print("✅ AddFoodViewModel - FoodItem verificato nel database: \(savedItem.name)")
            
            // Se iCloud è abilitato, forza una sincronizzazione più robusta
            if useiCloud {
                print("☁️ AddFoodViewModel - Forzo sincronizzazione CloudKit per FoodItem: \(savedItem.name)")
                
                // Forza più volte il save per assicurarsi che CloudKit riceva i dati
                try? modelContext.save()
                
                // Attendi un po' e forza di nuovo il save
                Task {
                    // Prima attesa: 2 secondi
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    await MainActor.run {
                        try? modelContext.save()
                        print("☁️ AddFoodViewModel - Secondo save forzato dopo 2 secondi")
                    }
                    
                    // Seconda attesa: altri 3 secondi (totale 5 secondi)
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        if let syncedItem = try? modelContext.fetch(verifyDescriptor).first {
                            print("☁️ AddFoodViewModel - FoodItem ancora presente dopo 5 secondi: \(syncedItem.name)")
                            print("☁️ AddFoodViewModel - Sincronizzazione CloudKit in corso...")
                        } else {
                            print("⚠️ AddFoodViewModel - FoodItem non trovato dopo sync CloudKit!")
                        }
                    }
                }
            }
        } else {
            print("⚠️ AddFoodViewModel - FoodItem non trovato dopo il salvataggio!")
        }
        
        // Programma notifiche se necessario
        if notify {
            // Carica le impostazioni per i giorni di anticipo
            let settingsDescriptor = FetchDescriptor<AppSettings>()
            if let settings = try? modelContext.fetch(settingsDescriptor).first {
                if settings.notificationsEnabled {
                    await notificationService.scheduleNotifications(
                        for: item,
                        daysBefore: settings.effectiveNotificationDays
                    )
                }
            } else {
                await notificationService.scheduleNotifications(for: item, daysBefore: 1)
            }
        }
        
        // Reset form
        reset()
    }
    
    func reset() {
        name = ""
        category = .fridge
        expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        quantity = 1
        notes = ""
        notify = true
        barcode = nil
        errorMessage = nil
        selectedPhoto = nil
        foodType = nil
        isGlutenFree = false
        isBio = false
        isVegan = false
        isLactoseFree = false
        isVegetarian = false
        isReady = false
        needsCooking = false
        isArtisan = false
        isSinglePortion = false
        isMultiPortion = false
        isFresh = false
        priceText = ""
        dateValidationError = nil
    }
    
    enum ValidationError: LocalizedError {
        case nameRequired
        case noContext
        case dateInPast
        
        var errorDescription: String? {
            switch self {
            case .nameRequired:
                return "Il nome del prodotto è obbligatorio"
            case .noContext:
                return "Errore di contesto"
            case .dateInPast:
                return "La data non può essere nel passato"
            }
        }
    }
}

