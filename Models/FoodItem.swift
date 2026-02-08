import Foundation
import SwiftData

/// Categoria di conservazione del cibo
enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }
    case fridge = "Frigorifero"
    case freezer = "Congelatore"
    case pantry = "Dispensa"
    
    var icon: String {
        switch self {
        case .fridge: return "refrigerator"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet"
        }
    }
    
    /// Icona in stile fill per uso in KPI e dettaglio prodotto
    var iconFill: String {
        switch self {
        case .fridge: return "refrigerator.fill"
        case .freezer: return "snowflake"
        case .pantry: return "cabinet.fill"
        }
    }
    
    var color: String {
        switch self {
        case .fridge: return "blue"
        case .freezer: return "cyan"
        case .pantry: return "orange"
        }
    }
}

/// Tipo di alimento (categoria culinaria) – stile Yazio / MyFitnessPal
struct FoodType: Codable, Hashable, Identifiable {
    var id: String { rawValue }
    let rawValue: String
    let icon: String
    
    // Categorie estese
    static let fruits = FoodType(rawValue: "Frutta", icon: "leaf.fill")
    static let vegetables = FoodType(rawValue: "Verdura", icon: "carrot.fill")
    static let potatoes = FoodType(rawValue: "Patate", icon: "leaf.fill")
    static let legumes = FoodType(rawValue: "Legumi", icon: "leaf.fill")
    static let cereals = FoodType(rawValue: "Cereali", icon: "circle.grid.hex.fill")
    static let pasta = FoodType(rawValue: "Pasta", icon: "circle.grid.hex.fill")
    static let rice = FoodType(rawValue: "Riso", icon: "circle.fill")
    static let bread = FoodType(rawValue: "Pane", icon: "square.fill")
    static let bakedGoods = FoodType(rawValue: "Prodotti da forno", icon: "birthday.cake.fill")
    static let meat = FoodType(rawValue: "Carne", icon: "fork.knife")
    static let poultry = FoodType(rawValue: "Pollame", icon: "fork.knife")
    static let fish = FoodType(rawValue: "Pesce", icon: "fish.fill")
    static let seafood = FoodType(rawValue: "Frutti di mare", icon: "drop.fill")
    static let coldCuts = FoodType(rawValue: "Salumi", icon: "fork.knife")
    static let eggs = FoodType(rawValue: "Uova", icon: "circle.fill")
    static let milk = FoodType(rawValue: "Latte", icon: "waterbottle.fill")
    static let yogurt = FoodType(rawValue: "Yogurt", icon: "cup.and.saucer.fill")
    static let cheese = FoodType(rawValue: "Formaggi", icon: "cube.fill")
    static let oils = FoodType(rawValue: "Oli", icon: "drop.fill")
    static let butterMargarine = FoodType(rawValue: "Burro e margarina", icon: "square.fill")
    static let saucesCondiments = FoodType(rawValue: "Salse e condimenti", icon: "drop.fill")
    static let sugar = FoodType(rawValue: "Zucchero", icon: "cube.fill")
    static let sweeteners = FoodType(rawValue: "Dolcificanti", icon: "drop.fill")
    static let sweets = FoodType(rawValue: "Dolci", icon: "birthday.cake.fill")
    static let biscuits = FoodType(rawValue: "Biscotti", icon: "circle.fill")
    static let chocolate = FoodType(rawValue: "Cioccolato", icon: "square.fill")
    static let sweetSnacks = FoodType(rawValue: "Snack dolci", icon: "circle.grid.3x3.fill")
    static let saltySnacks = FoodType(rawValue: "Snack salati", icon: "circle.grid.3x3.fill")
    static let iceCream = FoodType(rawValue: "Gelati", icon: "snowflake")
    static let readyMeals = FoodType(rawValue: "Piatti pronti", icon: "takeoutbag.and.cup.and.straw.fill")
    static let fastFood = FoodType(rawValue: "Fast food", icon: "takeoutbag.and.cup.and.straw.fill")
    static let canned = FoodType(rawValue: "Conserve", icon: "cylinder.fill")
    static let frozen = FoodType(rawValue: "Surgelati", icon: "snowflake")
    static let nutsSeeds = FoodType(rawValue: "Frutta secca e semi", icon: "leaf.fill")
    static let spicesHerbs = FoodType(rawValue: "Spezie ed erbe", icon: "leaf.fill")
    static let beverages = FoodType(rawValue: "Bevande", icon: "cup.and.saucer.fill")
    static let alcoholicBeverages = FoodType(rawValue: "Bevande alcoliche", icon: "wineglass.fill")
    static let supplements = FoodType(rawValue: "Integratori", icon: "pill.fill")
    static let sportsNutrition = FoodType(rawValue: "Alimenti per sportivi", icon: "dumbbell.fill")
    static let other = FoodType(rawValue: "Altro", icon: "questionmark.circle.fill")
    
    static var defaultTypes: [FoodType] {
        [
            .fruits, .vegetables, .potatoes, .legumes, .cereals, .pasta, .rice, .bread, .bakedGoods,
            .meat, .poultry, .fish, .seafood, .coldCuts, .eggs,
            .milk, .yogurt, .cheese,
            .oils, .butterMargarine, .saucesCondiments, .sugar, .sweeteners,
            .sweets, .biscuits, .chocolate, .sweetSnacks, .saltySnacks, .iceCream,
            .readyMeals, .fastFood, .canned, .frozen,
            .nutsSeeds, .spicesHerbs, .beverages, .alcoholicBeverages,
            .supplements, .sportsNutrition, .other
        ]
    }
    
    init(rawValue: String, icon: String = "tag.fill") {
        self.rawValue = rawValue
        self.icon = icon
    }
}

/// Stato di scadenza del cibo
enum ExpirationStatus: String, Hashable {
    case expired = "Scaduto"
    case today = "Oggi"
    case soon = "In scadenza"
    case safe = "Ancora buono"
    
    var color: String {
        switch self {
        case .expired: return "red"
        case .today: return "orange"
        case .soon: return "orange"
        case .safe: return "green"
        }
    }
    
    var priority: Int {
        switch self {
        case .expired: return 0
        case .today: return 1
        case .soon: return 2
        case .safe: return 3
        }
    }
}

@Model
final class FoodItem {
    var id: UUID = UUID()
    var name: String = ""
    var categoryRaw: String = FoodCategory.fridge.rawValue // Usa rawValue per CloudKit compatibility
    var expirationDate: Date = Date()
    var quantity: Int = 1
    var notes: String?
    var barcode: String?
    var createdAt: Date = Date()
    var lastUpdated: Date = Date()
    var notify: Bool = true
    var isConsumed: Bool = false
    var photoData: Data? // Foto del prodotto
    var foodType: FoodType? // Tipo di alimento (opzionale)
    
    // Etichette (tag / filtri)
    var isGlutenFree: Bool = false
    var isBio: Bool = false
    var isVegan: Bool = false
    var isLactoseFree: Bool = false
    var isVegetarian: Bool = false
    var isReady: Bool = false       // Pronto (da consumare così)
    var needsCooking: Bool = false  // Da cucinare
    var isArtisan: Bool = false     // Artigianale
    var isSinglePortion: Bool = false  // Monoporzione
    var isMultiPortion: Bool = false   // Multiporzione
    
    // Data in cui è stato consumato (per Storico consumi)
    var consumedDate: Date?
    
    // Gestione prodotti freschi e scadenze condizionali
    var isFresh: Bool = false // Prodotto fresco (scade dopo 3 giorni dalla data di aggiunta)
    var isOpened: Bool = false // Se il prodotto è aperto (scade dopo 3 giorni dall'apertura)
    var openedDate: Date? // Data di apertura (se aperto)
    var useAdvancedExpiry: Bool = false // Gestione avanzata: prodotto chiuso scade dopo 120 giorni dalla data di aggiunta (anti-oblio)
    
    // Computed property per category (compatibilità CloudKit)
    // @Transient indica a SwiftData di non salvare questa proprietà (viene salvato categoryRaw)
    @Transient
    var category: FoodCategory {
        get {
            FoodCategory(rawValue: categoryRaw) ?? .fridge
        }
        set {
            categoryRaw = newValue.rawValue
        }
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        category: FoodCategory,
        expirationDate: Date,
        quantity: Int = 1,
        notes: String? = nil,
        barcode: String? = nil,
        createdAt: Date = Date(),
        lastUpdated: Date = Date(),
        notify: Bool = true,
        isConsumed: Bool = false,
        consumedDate: Date? = nil,
        photoData: Data? = nil,
        foodType: FoodType? = nil,
        isGlutenFree: Bool = false,
        isBio: Bool = false,
        isVegan: Bool = false,
        isLactoseFree: Bool = false,
        isVegetarian: Bool = false,
        isReady: Bool = false,
        needsCooking: Bool = false,
        isArtisan: Bool = false,
        isSinglePortion: Bool = false,
        isMultiPortion: Bool = false,
        isFresh: Bool = false,
        isOpened: Bool = false,
        openedDate: Date? = nil,
        useAdvancedExpiry: Bool = false
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
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
        self.foodType = foodType
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
        self.isFresh = isFresh
        self.isOpened = isOpened
        self.openedDate = openedDate
        self.useAdvancedExpiry = useAdvancedExpiry
    }
    
    /// Calcola la data di scadenza effettiva secondo la logica semplificata
    /// Priorità: 1. fresco → 2. aperto → 3. chiuso+avanzata → 4. data stampata
    var effectiveExpirationDate: Date {
        let calendar = Calendar.current
        
        // 1. Prodotto fresco: scade dopo 3 giorni dalla data di aggiunta
        if isFresh {
            return calendar.date(byAdding: .day, value: 3, to: createdAt) ?? expirationDate
        }
        
        // 2. Prodotto aperto: scade dopo 3 giorni dalla data di apertura
        if isOpened, let openedDate = openedDate {
            return calendar.date(byAdding: .day, value: 3, to: openedDate) ?? expirationDate
        }
        
        // 3. Prodotto chiuso con gestione avanzata: scade dopo 120 giorni dalla data di aggiunta
        if useAdvancedExpiry && !isOpened {
            return calendar.date(byAdding: .day, value: 120, to: createdAt) ?? expirationDate
        }
        
        // 4. Fallback: usa la data di scadenza standard (prodotto confezionato con data)
        return expirationDate
    }
    
    /// Giorni rimanenti fino alla scadenza (considera logica custom se attiva)
    var daysRemaining: Int {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let effectiveDate = effectiveExpirationDate
        let startOfExpiration = calendar.startOfDay(for: effectiveDate)
        let components = calendar.dateComponents([.day], from: startOfToday, to: startOfExpiration)
        return components.day ?? 0
    }
    
    /// Stato di scadenza basato sui giorni rimanenti
    var expirationStatus: ExpirationStatus {
        let days = daysRemaining
        
        if days < 0 {
            return .expired
        } else if days == 0 {
            return .today
        } else if days <= 3 {
            return .soon
        } else {
            return .safe
        }
    }
    
    /// Verifica se l'item richiede una notifica
    var shouldNotify: Bool {
        guard notify, !isConsumed else { return false }
        let days = daysRemaining
        return days >= 0 && days <= 2
    }
    
    /// Progresso verso la scadenza (0.0 = appena aggiunto, 1.0 = scaduto)
    var expirationProgress: Double {
        let totalDays: Double
        let daysElapsed: Double
        
        // Calcola i giorni totali dalla creazione alla scadenza
        let calendar = Calendar.current
        let startOfCreation = calendar.startOfDay(for: createdAt)
        let startOfExpiration = calendar.startOfDay(for: effectiveExpirationDate)
        let totalComponents = calendar.dateComponents([.day], from: startOfCreation, to: startOfExpiration)
        totalDays = Double(totalComponents.day ?? 1)
        
        // Calcola i giorni trascorsi
        let startOfToday = calendar.startOfDay(for: Date())
        let elapsedComponents = calendar.dateComponents([.day], from: startOfCreation, to: startOfToday)
        daysElapsed = Double(elapsedComponents.day ?? 0)
        
        // Calcola il progresso (clamp tra 0 e 1)
        let progress = min(max(daysElapsed / totalDays, 0.0), 1.0)
        return progress
    }
    
    /// Frazione di tempo ancora rimanente prima della scadenza (1.0 = appena aggiunto, 0.0 = scaduto). Usata per la barra che si svuota.
    var expirationRemainingProgress: Double {
        let totalDays: Double
        let calendar = Calendar.current
        let startOfCreation = calendar.startOfDay(for: createdAt)
        let startOfExpiration = calendar.startOfDay(for: effectiveExpirationDate)
        let totalComponents = calendar.dateComponents([.day], from: startOfCreation, to: startOfExpiration)
        totalDays = Double(max(totalComponents.day ?? 1, 1))
        let remaining = Double(daysRemaining)
        return min(max(remaining / totalDays, 0.0), 1.0)
    }
}

