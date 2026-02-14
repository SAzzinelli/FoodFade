import Foundation
import SwiftData
import SwiftUI

/// Servizio per backup e ripristino dati
@MainActor
class BackupService {
    static let shared = BackupService()
    
    private init() {}
    
    // MARK: - Export
    
    /// Esporta tutti i dati in formato JSON
    func exportData(modelContext: ModelContext) throws -> Data {
        // Carica tutti i dati
        let foodItemsDescriptor = FetchDescriptor<FoodItem>()
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let customTypesDescriptor = FetchDescriptor<CustomFoodType>()
        
        let foodItems = try modelContext.fetch(foodItemsDescriptor)
        let settings = try modelContext.fetch(settingsDescriptor)
        let profiles = try modelContext.fetch(profileDescriptor)
        let customTypes = try modelContext.fetch(customTypesDescriptor)
        
        // Crea struttura dati per export
        let exportData = BackupData(
            version: "1.0",
            exportDate: Date(),
            foodItems: foodItems.map { item in
                BackupFoodItem(
                    id: item.id,
                    name: item.name,
                    category: item.category.rawValue,
                    expirationDate: item.expirationDate,
                    quantity: item.quantity,
                    notes: item.notes,
                    barcode: item.barcode,
                    createdAt: item.createdAt,
                    lastUpdated: item.lastUpdated,
                    notify: item.notify,
                    isConsumed: item.isConsumed,
                    consumedDate: item.consumedDate,
                    photoData: item.photoData,
                    foodTypeRaw: item.foodType?.rawValue,
                    isFresh: item.isFresh,
                    isOpened: item.isOpened,
                    openedDate: item.openedDate,
                    useAdvancedExpiry: item.useAdvancedExpiry,
                    price: item.price,
                    isGlutenFree: item.isGlutenFree,
                    isBio: item.isBio,
                    isVegan: item.isVegan,
                    isLactoseFree: item.isLactoseFree,
                    isVegetarian: item.isVegetarian,
                    isReady: item.isReady,
                    needsCooking: item.needsCooking,
                    isArtisan: item.isArtisan,
                    isSinglePortion: item.isSinglePortion,
                    isMultiPortion: item.isMultiPortion
                )
            },
            settings: settings.first.map { s in
                BackupSettings(
                    notificationsEnabled: s.notificationsEnabled,
                    notificationDaysBefore: s.notificationDaysBefore,
                    customNotificationDays: s.customNotificationDays,
                    iCloudSyncEnabled: s.iCloudSyncEnabled,
                    smartSuggestionsEnabled: s.smartSuggestionsEnabled,
                    appearanceModeRaw: s.appearanceModeRaw,
                    animationsEnabled: s.animationsEnabled,
                    accentColorRaw: s.accentColorRaw,
                    progressRingModeRaw: s.progressRingModeRaw,
                    homeSummaryStyleRaw: s.homeSummaryStyleRaw,
                    expirationInputMethodRaw: s.expirationInputMethodRaw,
                    hasChosenCloudUsage: s.hasChosenCloudUsage,
                    shoppingListTabEnabled: s.shoppingListTabEnabled
                )
            },
            profiles: profiles.map { p in
                BackupProfile(
                    id: p.id,
                    firstName: p.firstName,
                    lastName: p.lastName,
                    hasCompletedOnboarding: p.hasCompletedOnboarding
                )
            },
            customFoodTypes: customTypes.map { t in
                BackupCustomFoodType(
                    id: t.id,
                    name: t.name,
                    icon: t.icon,
                    createdAt: t.createdAt
                )
            }
        )
        
        // Codifica in JSON
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        return try encoder.encode(exportData)
    }
    
    // MARK: - Import
    
    /// Importa dati da JSON
    func importData(
        from data: Data,
        modelContext: ModelContext,
        mergeMode: ImportMode
    ) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let backupData = try decoder.decode(BackupData.self, from: data)
        
        var importedCount = 0
        var updatedCount = 0
        var skippedCount = 0
        
        switch mergeMode {
        case .replace:
            // Elimina tutto e importa
            try clearAllData(modelContext: modelContext)
            importedCount = try importAllItems(backupData: backupData, modelContext: modelContext)
            
        case .merge:
            // Merge intelligente: aggiunge solo nuovi, evita duplicati
            let result = try mergeItems(backupData: backupData, modelContext: modelContext)
            importedCount = result.imported
            updatedCount = result.updated
            skippedCount = result.skipped
        }
        
        return ImportResult(
            imported: importedCount,
            updated: updatedCount,
            skipped: skippedCount,
            totalInBackup: backupData.foodItems.count
        )
    }
    
    // MARK: - Helper Methods
    
    private func clearAllData(modelContext: ModelContext) throws {
        // Elimina tutti i FoodItem
        let foodItemsDescriptor = FetchDescriptor<FoodItem>()
        let foodItems = try modelContext.fetch(foodItemsDescriptor)
        for item in foodItems {
            modelContext.delete(item)
        }
        
        // Elimina tutte le AppSettings (verranno ricreate)
        let settingsDescriptor = FetchDescriptor<AppSettings>()
        let settings = try modelContext.fetch(settingsDescriptor)
        for setting in settings {
            modelContext.delete(setting)
        }
        
        // Elimina tutti i UserProfile
        let profileDescriptor = FetchDescriptor<UserProfile>()
        let profiles = try modelContext.fetch(profileDescriptor)
        for profile in profiles {
            modelContext.delete(profile)
        }
        
        // Elimina tutti i CustomFoodType
        let customTypesDescriptor = FetchDescriptor<CustomFoodType>()
        let customTypes = try modelContext.fetch(customTypesDescriptor)
        for type in customTypes {
            modelContext.delete(type)
        }
        
        try modelContext.save()
    }
    
    private func importAllItems(backupData: BackupData, modelContext: ModelContext) throws -> Int {
        var count = 0
        
        // Importa FoodItems
        for backupItem in backupData.foodItems {
            let category = FoodCategory(rawValue: backupItem.category) ?? .pantry
            let foodType = backupItem.foodTypeRaw.flatMap { rawValue in
                FoodType.defaultTypes.first { $0.rawValue == rawValue }
            }
            
            let item = FoodItem(
                id: backupItem.id,
                name: backupItem.name,
                category: category,
                expirationDate: backupItem.expirationDate,
                quantity: backupItem.quantity,
                notes: backupItem.notes,
                barcode: backupItem.barcode,
                createdAt: backupItem.createdAt,
                lastUpdated: backupItem.lastUpdated,
                notify: backupItem.notify,
                isConsumed: backupItem.isConsumed,
                consumedDate: backupItem.consumedDate,
                photoData: backupItem.photoData,
                foodType: foodType,
                isGlutenFree: backupItem.isGlutenFree,
                isBio: backupItem.isBio,
                isVegan: backupItem.isVegan,
                isLactoseFree: backupItem.isLactoseFree,
                isVegetarian: backupItem.isVegetarian,
                isReady: backupItem.isReady,
                needsCooking: backupItem.needsCooking,
                isArtisan: backupItem.isArtisan,
                isSinglePortion: backupItem.isSinglePortion,
                isMultiPortion: backupItem.isMultiPortion,
                isFresh: backupItem.isFresh,
                isOpened: backupItem.isOpened,
                openedDate: backupItem.openedDate,
                useAdvancedExpiry: backupItem.useAdvancedExpiry,
                price: backupItem.price
            )
            
            modelContext.insert(item)
            count += 1
        }
        
        // Importa Settings
        if let backupSettings = backupData.settings {
            let settings = AppSettings(
                notificationsEnabled: backupSettings.notificationsEnabled,
                notificationDaysBefore: backupSettings.notificationDaysBefore,
                customNotificationDays: backupSettings.customNotificationDays,
                iCloudSyncEnabled: backupSettings.iCloudSyncEnabled,
                smartSuggestionsEnabled: backupSettings.smartSuggestionsEnabled,
                appearanceMode: AppearanceMode(rawValue: backupSettings.appearanceModeRaw) ?? .system,
                animationsEnabled: backupSettings.animationsEnabled,
                accentColor: (backupSettings.accentColorRaw == "default" ? .orange : AccentColor(rawValue: backupSettings.accentColorRaw) ?? .natural),
                progressRingMode: ProgressRingMode(rawValue: backupSettings.progressRingModeRaw) ?? .safeItems,
                homeSummaryStyle: HomeSummaryStyle(rawValue: backupSettings.homeSummaryStyleRaw ?? HomeSummaryStyle.ring.rawValue) ?? .ring,
                expirationInputMethod: ExpirationInputMethod(rawValue: backupSettings.expirationInputMethodRaw ?? ExpirationInputMethod.calendar.rawValue) ?? .calendar,
                hasChosenCloudUsage: backupSettings.hasChosenCloudUsage ?? false,
                shoppingListTabEnabled: backupSettings.shoppingListTabEnabled ?? false
            )
            modelContext.insert(settings)
        }
        
        // Importa Profiles
        for backupProfile in backupData.profiles {
            let profile = UserProfile(
                id: backupProfile.id,
                firstName: backupProfile.firstName,
                lastName: backupProfile.lastName,
                hasCompletedOnboarding: backupProfile.hasCompletedOnboarding
            )
            modelContext.insert(profile)
        }
        
        // Importa CustomFoodTypes
        for backupType in backupData.customFoodTypes {
            let customType = CustomFoodType(
                name: backupType.name,
                icon: backupType.icon,
                id: backupType.id,
                createdAt: backupType.createdAt
            )
            modelContext.insert(customType)
        }
        
        try modelContext.save()
        return count
    }
    
    private func mergeItems(backupData: BackupData, modelContext: ModelContext) throws -> (imported: Int, updated: Int, skipped: Int) {
        var imported = 0
        var updated = 0
        var skipped = 0
        
        // Carica items esistenti
        let existingDescriptor = FetchDescriptor<FoodItem>()
        let existingItems = try modelContext.fetch(existingDescriptor)
        
        // Crea mappa per ricerca veloce (nome + categoria + data scadenza)
        var existingMap: [String: FoodItem] = [:]
        for item in existingItems {
            let key = makeItemKey(item: item)
            existingMap[key] = item
        }
        
        // Processa items dal backup
        for backupItem in backupData.foodItems {
            let category = FoodCategory(rawValue: backupItem.category) ?? .pantry
            let key = makeItemKey(
                name: backupItem.name,
                category: category,
                expirationDate: effectiveExpirationDate(for: backupItem)
            )
            
            if let existingItem = existingMap[key] {
                // Item esiste già: aggiorna se il backup è più recente
                if backupItem.lastUpdated > existingItem.lastUpdated {
                    let foodType = backupItem.foodTypeRaw.flatMap { rawValue in
                        FoodType.defaultTypes.first { $0.rawValue == rawValue }
                    }

                    existingItem.name = backupItem.name
                    existingItem.category = category
                    existingItem.expirationDate = backupItem.expirationDate
                    existingItem.quantity = backupItem.quantity
                    existingItem.notes = backupItem.notes
                    existingItem.barcode = backupItem.barcode
                    existingItem.lastUpdated = backupItem.lastUpdated
                    existingItem.notify = backupItem.notify
                    existingItem.isConsumed = backupItem.isConsumed
                    existingItem.consumedDate = backupItem.consumedDate
                    existingItem.photoData = backupItem.photoData
                    existingItem.foodType = foodType
                    existingItem.isFresh = backupItem.isFresh
                    existingItem.isOpened = backupItem.isOpened
                    existingItem.openedDate = backupItem.openedDate
                    existingItem.useAdvancedExpiry = backupItem.useAdvancedExpiry
                    existingItem.price = backupItem.price
                    existingItem.isGlutenFree = backupItem.isGlutenFree
                    existingItem.isBio = backupItem.isBio
                    existingItem.isVegan = backupItem.isVegan
                    existingItem.isLactoseFree = backupItem.isLactoseFree
                    existingItem.isVegetarian = backupItem.isVegetarian
                    existingItem.isReady = backupItem.isReady
                    existingItem.needsCooking = backupItem.needsCooking
                    existingItem.isArtisan = backupItem.isArtisan
                    existingItem.isSinglePortion = backupItem.isSinglePortion
                    existingItem.isMultiPortion = backupItem.isMultiPortion
                    updated += 1
                } else {
                    skipped += 1
                }
            } else {
                // Nuovo item: importa
                let foodType = backupItem.foodTypeRaw.flatMap { rawValue in
                    FoodType.defaultTypes.first { $0.rawValue == rawValue }
                }
                
                let item = FoodItem(
                    id: backupItem.id,
                    name: backupItem.name,
                    category: category,
                    expirationDate: backupItem.expirationDate,
                    quantity: backupItem.quantity,
                    notes: backupItem.notes,
                    barcode: backupItem.barcode,
                    createdAt: backupItem.createdAt,
                    lastUpdated: backupItem.lastUpdated,
                    notify: backupItem.notify,
                    isConsumed: backupItem.isConsumed,
                    consumedDate: backupItem.consumedDate,
                    photoData: backupItem.photoData,
                    foodType: foodType,
                    isGlutenFree: backupItem.isGlutenFree,
                    isBio: backupItem.isBio,
                    isVegan: backupItem.isVegan,
                    isLactoseFree: backupItem.isLactoseFree,
                    isVegetarian: backupItem.isVegetarian,
                    isReady: backupItem.isReady,
                    needsCooking: backupItem.needsCooking,
                    isArtisan: backupItem.isArtisan,
                    isSinglePortion: backupItem.isSinglePortion,
                    isMultiPortion: backupItem.isMultiPortion,
                    isFresh: backupItem.isFresh,
                    isOpened: backupItem.isOpened,
                    openedDate: backupItem.openedDate,
                    useAdvancedExpiry: backupItem.useAdvancedExpiry,
                    price: backupItem.price
                )
                
                modelContext.insert(item)
                imported += 1
            }
        }
        
        try modelContext.save()
        return (imported, updated, skipped)
    }
    
    private func effectiveExpirationDate(for backupItem: BackupFoodItem) -> Date {
        let calendar = Calendar.current
        if backupItem.isFresh {
            return calendar.date(byAdding: .day, value: 3, to: backupItem.createdAt) ?? backupItem.expirationDate
        }
        if backupItem.isOpened, let openedDate = backupItem.openedDate {
            return calendar.date(byAdding: .day, value: 3, to: openedDate) ?? backupItem.expirationDate
        }
        if backupItem.useAdvancedExpiry && !backupItem.isOpened {
            return calendar.date(byAdding: .day, value: 120, to: backupItem.createdAt) ?? backupItem.expirationDate
        }
        return backupItem.expirationDate
    }

    private func makeItemKey(item: FoodItem) -> String {
        makeItemKey(
            name: item.name,
            category: item.category,
            expirationDate: item.effectiveExpirationDate
        )
    }
    
    private func makeItemKey(name: String, category: FoodCategory, expirationDate: Date) -> String {
        let calendar = Calendar.current
        let dateString = calendar.dateComponents([.year, .month, .day], from: expirationDate).description
        return "\(name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))_\(category.rawValue)_\(dateString)"
    }
    
    // MARK: - iCloud Detection
    
    /// Verifica se ci sono dati disponibili su iCloud
    func checkiCloudDataAvailable(modelContext: ModelContext) async -> Bool {
        // SwiftData con CloudKit sincronizza automaticamente, quindi se ci sono dati
        // su iCloud, verranno scaricati automaticamente. Possiamo verificare se ci sono
        // più record di quelli locali o se ci sono record con timestamp più recenti.
        
        // Per semplicità, verifichiamo se ci sono dati che potrebbero essere stati sincronizzati
        // Controlliamo se ci sono items con date di creazione molto vecchie (potrebbero essere da iCloud)
        let descriptor = FetchDescriptor<FoodItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        do {
            let items = try modelContext.fetch(descriptor)
            // Se ci sono items e l'app è appena stata installata (hasSeenWelcome = false),
            // probabilmente sono dati da iCloud
            return !items.isEmpty
        } catch {
            return false
        }
    }
}

// MARK: - Data Models

/// Modalità di importazione dati
enum ImportMode {
    case replace  // Sostituisce tutto
    case merge    // Merge intelligente
}

/// Risultato dell'importazione
struct ImportResult {
    let imported: Int
    let updated: Int
    let skipped: Int
    let totalInBackup: Int
}

struct BackupData: Codable {
    let version: String
    let exportDate: Date
    let foodItems: [BackupFoodItem]
    let settings: BackupSettings?
    let profiles: [BackupProfile]
    let customFoodTypes: [BackupCustomFoodType]
}

struct BackupFoodItem: Codable {
    let id: UUID
    let name: String
    let category: String
    let expirationDate: Date
    let quantity: Int
    let notes: String?
    let barcode: String?
    let createdAt: Date
    let lastUpdated: Date
    let notify: Bool
    let isConsumed: Bool
    let consumedDate: Date?
    let photoData: Data?
    let foodTypeRaw: String?
    let isFresh: Bool
    let isOpened: Bool
    let openedDate: Date?
    let useAdvancedExpiry: Bool
    let price: Double?
    let isGlutenFree: Bool
    let isBio: Bool
    let isVegan: Bool
    let isLactoseFree: Bool
    let isVegetarian: Bool
    let isReady: Bool
    let needsCooking: Bool
    let isArtisan: Bool
    let isSinglePortion: Bool
    let isMultiPortion: Bool
    
    init(id: UUID, name: String, category: String, expirationDate: Date, quantity: Int, notes: String?, barcode: String?, createdAt: Date, lastUpdated: Date, notify: Bool, isConsumed: Bool, consumedDate: Date?, photoData: Data?, foodTypeRaw: String?, isFresh: Bool, isOpened: Bool, openedDate: Date?, useAdvancedExpiry: Bool, price: Double?, isGlutenFree: Bool = false, isBio: Bool = false, isVegan: Bool = false, isLactoseFree: Bool = false, isVegetarian: Bool = false, isReady: Bool = false, needsCooking: Bool = false, isArtisan: Bool = false, isSinglePortion: Bool = false, isMultiPortion: Bool = false) {
        self.id = id
        self.name = name
        self.category = category
        self.expirationDate = expirationDate
        self.quantity = quantity
        self.notes = notes
        self.barcode = barcode
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
        self.notify = notify
        self.isConsumed = isConsumed
        self.consumedDate = consumedDate
        self.photoData = photoData
        self.foodTypeRaw = foodTypeRaw
        self.isFresh = isFresh
        self.isOpened = isOpened
        self.openedDate = openedDate
        self.useAdvancedExpiry = useAdvancedExpiry
        self.price = price
        self.isGlutenFree = isGlutenFree
        self.isBio = isBio
        self.isVegan = isVegan
        self.isLactoseFree = isLactoseFree
        self.isVegetarian = isVegetarian
        self.isReady = isReady
        self.needsCooking = needsCooking
        self.isArtisan = isArtisan
        self.isSinglePortion = isSinglePortion
        self.isMultiPortion = isMultiPortion
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        category = try c.decode(String.self, forKey: .category)
        expirationDate = try c.decode(Date.self, forKey: .expirationDate)
        quantity = try c.decode(Int.self, forKey: .quantity)
        notes = try c.decodeIfPresent(String.self, forKey: .notes)
        barcode = try c.decodeIfPresent(String.self, forKey: .barcode)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        lastUpdated = try c.decode(Date.self, forKey: .lastUpdated)
        notify = try c.decode(Bool.self, forKey: .notify)
        isConsumed = try c.decode(Bool.self, forKey: .isConsumed)
        consumedDate = try c.decodeIfPresent(Date.self, forKey: .consumedDate)
        photoData = try c.decodeIfPresent(Data.self, forKey: .photoData)
        foodTypeRaw = try c.decodeIfPresent(String.self, forKey: .foodTypeRaw)
        isFresh = try c.decode(Bool.self, forKey: .isFresh)
        isOpened = try c.decode(Bool.self, forKey: .isOpened)
        openedDate = try c.decodeIfPresent(Date.self, forKey: .openedDate)
        useAdvancedExpiry = try c.decode(Bool.self, forKey: .useAdvancedExpiry)
        price = try c.decodeIfPresent(Double.self, forKey: .price)
        isGlutenFree = try c.decodeIfPresent(Bool.self, forKey: .isGlutenFree) ?? false
        isBio = try c.decodeIfPresent(Bool.self, forKey: .isBio) ?? false
        isVegan = try c.decodeIfPresent(Bool.self, forKey: .isVegan) ?? false
        isLactoseFree = try c.decodeIfPresent(Bool.self, forKey: .isLactoseFree) ?? false
        isVegetarian = try c.decodeIfPresent(Bool.self, forKey: .isVegetarian) ?? false
        isReady = try c.decodeIfPresent(Bool.self, forKey: .isReady) ?? false
        needsCooking = try c.decodeIfPresent(Bool.self, forKey: .needsCooking) ?? false
        isArtisan = try c.decodeIfPresent(Bool.self, forKey: .isArtisan) ?? false
        isSinglePortion = try c.decodeIfPresent(Bool.self, forKey: .isSinglePortion) ?? false
        isMultiPortion = try c.decodeIfPresent(Bool.self, forKey: .isMultiPortion) ?? false
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, name, category, expirationDate, quantity, notes, barcode, createdAt, lastUpdated, notify, isConsumed, consumedDate, photoData, foodTypeRaw, isFresh, isOpened, openedDate, useAdvancedExpiry, price
        case isGlutenFree, isBio, isVegan, isLactoseFree, isVegetarian, isReady, needsCooking, isArtisan, isSinglePortion, isMultiPortion
    }
}

struct BackupSettings: Codable {
    let notificationsEnabled: Bool
    let notificationDaysBefore: Int
    let customNotificationDays: Int
    let iCloudSyncEnabled: Bool
    let smartSuggestionsEnabled: Bool
    let appearanceModeRaw: String
    let animationsEnabled: Bool
    let accentColorRaw: String
    let progressRingModeRaw: String
    let homeSummaryStyleRaw: String?
    let expirationInputMethodRaw: String?
    let hasChosenCloudUsage: Bool?
    let shoppingListTabEnabled: Bool?
    
    init(notificationsEnabled: Bool, notificationDaysBefore: Int, customNotificationDays: Int, iCloudSyncEnabled: Bool, smartSuggestionsEnabled: Bool, appearanceModeRaw: String, animationsEnabled: Bool, accentColorRaw: String, progressRingModeRaw: String, homeSummaryStyleRaw: String?, expirationInputMethodRaw: String?, hasChosenCloudUsage: Bool? = nil, shoppingListTabEnabled: Bool? = nil) {
        self.notificationsEnabled = notificationsEnabled
        self.notificationDaysBefore = notificationDaysBefore
        self.customNotificationDays = customNotificationDays
        self.iCloudSyncEnabled = iCloudSyncEnabled
        self.smartSuggestionsEnabled = smartSuggestionsEnabled
        self.appearanceModeRaw = appearanceModeRaw
        self.animationsEnabled = animationsEnabled
        self.accentColorRaw = accentColorRaw
        self.progressRingModeRaw = progressRingModeRaw
        self.homeSummaryStyleRaw = homeSummaryStyleRaw
        self.expirationInputMethodRaw = expirationInputMethodRaw
        self.hasChosenCloudUsage = hasChosenCloudUsage
        self.shoppingListTabEnabled = shoppingListTabEnabled
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        notificationsEnabled = try c.decode(Bool.self, forKey: .notificationsEnabled)
        notificationDaysBefore = try c.decode(Int.self, forKey: .notificationDaysBefore)
        customNotificationDays = try c.decode(Int.self, forKey: .customNotificationDays)
        iCloudSyncEnabled = try c.decode(Bool.self, forKey: .iCloudSyncEnabled)
        smartSuggestionsEnabled = try c.decode(Bool.self, forKey: .smartSuggestionsEnabled)
        appearanceModeRaw = try c.decode(String.self, forKey: .appearanceModeRaw)
        animationsEnabled = try c.decode(Bool.self, forKey: .animationsEnabled)
        accentColorRaw = try c.decode(String.self, forKey: .accentColorRaw)
        progressRingModeRaw = try c.decode(String.self, forKey: .progressRingModeRaw)
        homeSummaryStyleRaw = try c.decodeIfPresent(String.self, forKey: .homeSummaryStyleRaw)
        expirationInputMethodRaw = try c.decodeIfPresent(String.self, forKey: .expirationInputMethodRaw)
        hasChosenCloudUsage = try c.decodeIfPresent(Bool.self, forKey: .hasChosenCloudUsage)
        shoppingListTabEnabled = try c.decodeIfPresent(Bool.self, forKey: .shoppingListTabEnabled)
    }
    
    private enum CodingKeys: String, CodingKey {
        case notificationsEnabled, notificationDaysBefore, customNotificationDays, iCloudSyncEnabled, smartSuggestionsEnabled
        case appearanceModeRaw, animationsEnabled, accentColorRaw, progressRingModeRaw, homeSummaryStyleRaw, expirationInputMethodRaw
        case hasChosenCloudUsage, shoppingListTabEnabled
    }
}

struct BackupProfile: Codable {
    let id: UUID
    let firstName: String?
    let lastName: String?
    let hasCompletedOnboarding: Bool
}

struct BackupCustomFoodType: Codable {
    let id: UUID
    let name: String
    let icon: String
    let createdAt: Date
}

