import Foundation
import SwiftData

// MARK: - Dominio FoodFade (sopra OFF / tipi app)

/// Dominio culinario: dolce, salato, neutro (può andare in entrambi con limiti)
enum FoodFadeDomain: String, CaseIterable {
    case dolce
    case salato
    case neutro
}

// MARK: - Ruolo ingrediente (OBBLIGATORIO)

/// Ruolo dell'ingrediente nella ricetta. Regole: max 1 protagonista, max 1 base.
enum IngredientRole: String, CaseIterable {
    case base
    case protagonista
    case supporto
    case aroma
    case topping
}

// MARK: - Categoria ricetta FoodFade

/// Le ricette non nascono da OFF ma da queste categorie. Ogni categoria ha un dominio ammesso.
enum FoodFadeRecipeCategory: String, CaseIterable {
    case dolce_da_forno
    case dessert_al_cucchiaio
    case colazione
    case snack_dolce
    case primo_piatto
    case secondo_piatto
    case contorno
    case snack_salato
    
    /// Dominio ammesso per questa categoria
    var allowedDomain: FoodFadeDomain? {
        switch self {
        case .dolce_da_forno, .dessert_al_cucchiaio, .colazione, .snack_dolce:
            return .dolce
        case .primo_piatto, .secondo_piatto, .contorno, .snack_salato:
            return .salato
        }
    }
    
    /// Neutro è sempre ammesso come supporto
    var displayName: String {
        switch self {
        case .dolce_da_forno: return "Dolce da forno"
        case .dessert_al_cucchiaio: return "Dessert al cucchiaio"
        case .colazione: return "Colazione"
        case .snack_dolce: return "Snack dolce"
        case .primo_piatto: return "Primo piatto"
        case .secondo_piatto: return "Secondo piatto"
        case .contorno: return "Contorno"
        case .snack_salato: return "Snack salato"
        }
    }
}

// MARK: - Risultato validazione

struct RecipeRejection: Error {
    let reason: String
    let alternatives: [String]
}

struct ValidatedRecipeInput {
    let category: FoodFadeRecipeCategory
    let items: [(item: FoodItem, role: IngredientRole)]
    let domain: FoodFadeDomain
}

// MARK: - Logica culinaria FoodFade

/// Layer sopra i dati: mappa ingredienti → dominio, assegna ruoli, applica regole HARD.
/// L'AI non decide nulla di strutturale: riceve solo combinazioni già validate.
enum FoodFadeCulinaryLogic {
    
    // MARK: - Mapping FoodType / nome → Dominio
    
    /// Parole chiave che forzano dominio DOLCE (biscotti, cioccolato, torte, etc.)
    private static let dolceKeywords: Set<String> = [
        "biscotto", "biscotti", "cioccolato", "cioccolata", "torta", "torte", "dolce", "dolci",
        "marmellata", "crema", "nutella", "miele", "zucchero", "croissant", "brioche",
        "pasta frolla", "bignè", "tiramisù", "gelato", "yogurt alla frutta", "budino",
        "wafer", "merenda", "canditi", "cacao", "panna", "plumcake", "muffin", "pancake",
        "cereali", "barretta", "cioccolatino", "caramella", "confettura", "fetta biscottata",
        "pan di spagna", "savoiardo", "amaretti", "cantucci", "cannella", "vaniglia",
        "crema pasticcera", "frutta candita", "mostarda di frutta"
    ]
    
    /// Parole chiave che forzano dominio SALATO (pomodoro, cipolla, aglio, etc.)
    private static let salatoKeywords: Set<String> = [
        "pomodoro", "pomodori", "salsa al pomodoro", "passata", "cipolla", "aglio",
        "carne", "pesce", "salmone", "tonno", "formaggio", "formaggi", "salume", "prosciutto",
        "verdura", "verdure", "insalata", "zucchina", "melanzana", "peperone",
        "pasta al sugo", "risotto", "brodo", "soffritto", "sugo", "rosolato",
        "acciughe", "olive", "capperi", "mozzarella", "parmigiano", "gorgonzola",
        "speck", "pancetta", "salsiccia", "pollo", "tacchino", "legumi", "fagioli",
        "ceci", "lenticchie", "piselli", "carota", "sedano", "spinaci", "rucola",
        "funghi", "peperoncino", "senape", "maionese", "ketchup", "cous cous",
        "orzo", "farro", "quinoa", "baccalà", "cozze", "vongole", "gamberi", "calamari"
    ]
    
    /// Dominio per FoodType (mappatura principale)
    private static func domain(for foodType: FoodType?) -> FoodFadeDomain {
        guard let t = foodType else { return .neutro }
        switch t.rawValue.lowercased() {
        case "verdure", "carne", "pesce", "sughi pronti": return .salato
        case "frutta", "latticini", "pasta", "riso", "pane", "bevande", "snack", "surgelati", "conserve", "altro": return .neutro
        default: return .neutro
        }
    }
    
    /// Dominio per nome prodotto (override con parole chiave)
    static func domain(for item: FoodItem) -> FoodFadeDomain {
        let nameLower = item.name.lowercased()
        for kw in dolceKeywords where nameLower.contains(kw) { return .dolce }
        for kw in salatoKeywords where nameLower.contains(kw) { return .salato }
        return domain(for: item.foodType)
    }
    
    // MARK: - Assegnazione ruoli (semplificata)
    
    /// Assegna ruoli: max 1 base, max 1 protagonista; resto supporto/aroma/topping.
    private static func assignRoles(items: [FoodItem], domain: FoodFadeDomain) -> [(item: FoodItem, role: IngredientRole)] {
        guard !items.isEmpty else { return [] }
        var result: [(item: FoodItem, role: IngredientRole)] = []
        var hasBase = false
        var hasProtagonista = false
        for item in items {
            let d = Self.domain(for: item)
            if d == domain {
                if !hasProtagonista {
                    result.append((item: item, role: .protagonista))
                    hasProtagonista = true
                } else if !hasBase {
                    result.append((item: item, role: .base))
                    hasBase = true
                } else {
                    result.append((item: item, role: .supporto))
                }
            } else if d == .neutro {
                if !hasBase {
                    result.append((item: item, role: .base))
                    hasBase = true
                } else {
                    result.append((item: item, role: .supporto))
                }
            } else {
                result.append((item: item, role: .supporto))
            }
        }
        return result
    }
    
    // MARK: - Regole HARD (if → reject)
    
    /// Divieti assoluti: combinazioni che non devono mai arrivare all'AI
    private static func checkHardRules(items: [FoodItem]) -> RecipeRejection? {
        let domains = items.map { domain(for: $0) }
        let hasDolce = domains.contains(.dolce)
        let hasSalato = domains.contains(.salato)
        let names = items.map { $0.name.lowercased() }
        
        // ❌ dolce + pomodoro
        if hasDolce && names.contains(where: { $0.contains("pomodoro") }) {
            return RecipeRejection(
                reason: "Non è possibile combinare ingredienti dolci con pomodoro in una ricetta coerente.",
                alternatives: ["Scegli solo ingredienti dolci per un dessert.", "Scegli solo ingredienti salati per un piatto unico."]
            )
        }
        // ❌ dolce + cipolla/aglio
        if hasDolce && (names.contains(where: { $0.contains("cipolla") }) || names.contains(where: { $0.contains("aglio") })) {
            return RecipeRejection(
                reason: "Dolce e cipolla/aglio non sono compatibili in una ricetta.",
                alternatives: ["Usa solo ingredienti dolci per una ricetta da forno o dessert.", "Escludi gli ingredienti dolci per un piatto salato."]
            )
        }
        // ❌ due protagonisti di domini diversi (dolce + salato protagonisti)
        if hasDolce && hasSalato {
            let dolceCount = domains.filter { $0 == .dolce }.count
            let salatoCount = domains.filter { $0 == .salato }.count
            if dolceCount >= 1 && salatoCount >= 1 {
                return RecipeRejection(
                    reason: "Hai mixato ingredienti dolci e salati come protagonisti. Una ricetta deve essere coerente: dolce oppure salata.",
                    alternatives: ["Scegli solo ingredienti per un piatto dolce (es. biscotti, yogurt, frutta).", "Scegli solo ingredienti per un piatto salato (es. pasta, verdure, formaggio)."]
                )
            }
        }
        // ❌ biscotti come base salata
        if names.contains(where: { $0.contains("biscotto") }) && hasSalato {
            return RecipeRejection(
                reason: "I biscotti non possono essere la base di un piatto salato.",
                alternatives: ["Usa i biscotti per un dolce (es. cheesecake, tiramisù).", "Per un piatto salato scegli pasta, riso o pane."]
            )
        }
        // ❌ dolce + brodo / soffritto / sugo (contesto salato)
        let hasSalatoContext = names.contains(where: { n in
            n.contains("soffritto") || n.contains("brodo") || n.contains("sugo") || n.contains("rosolato")
        })
        if hasDolce && hasSalatoContext {
            return RecipeRejection(
                reason: "Dolce e tecniche da cucina salata (soffritto, brodo, sugo) non sono compatibili.",
                alternatives: ["Scegli solo ingredienti dolci per un dessert.", "Per un piatto salato escludi biscotti, marmellata, cioccolato."]
            )
        }
        // ❌ dolce + carne/pesce espliciti (rinforzo)
        let hasCarnePesce = names.contains(where: { n in
            n.contains("carne") || n.contains("pesce") || n.contains("tonno") || n.contains("salmone") ||
            n.contains("pollo") || n.contains("prosciutto") || n.contains("salsiccia") || n.contains("pancetta")
        })
        if hasDolce && hasCarnePesce {
            return RecipeRejection(
                reason: "Non si possono combinare ingredienti dolci con carne o pesce in una ricetta.",
                alternatives: ["Scegli solo ingredienti dolci (es. frutta, yogurt, biscotti).", "Per un secondo o primo scegli solo ingredienti salati."]
            )
        }
        // ❌ gelato / marmellata come ingrediente in piatto salato
        let hasDolceAsIngredient = names.contains(where: { n in
            n.contains("gelato") || n.contains("marmellata") || n.contains("nutella") || n.contains("cioccolato")
        })
        if hasDolceAsIngredient && hasSalato {
            return RecipeRejection(
                reason: "Gelato, marmellata e cioccolato non vanno in piatti salati.",
                alternatives: ["Usali per un dessert o una colazione.", "Per un piatto unico scegli solo ingredienti salati."]
            )
        }
        if items.count < 2 {
            return RecipeRejection(
                reason: "Servono almeno due ingredienti per una ricetta.",
                alternatives: ["Aggiungi altri ingredienti dall'inventario."]
            )
        }
        return nil
    }
    
    /// Vincoli strutturali: max 6 ingredienti, almeno 1 base coerente
    private static func checkStructuralRules(items: [FoodItem]) -> RecipeRejection? {
        if items.count > 6 {
            return RecipeRejection(
                reason: "Troppi ingredienti selezionati. Per una ricetta chiara usa al massimo 6 ingredienti.",
                alternatives: ["Seleziona da 2 a 6 ingredienti dall'inventario."]
            )
        }
        return nil
    }
    
    // MARK: - Inferenza categoria da domini
    
    private static func inferCategory(from items: [FoodItem], domains: [FoodFadeDomain]) -> FoodFadeRecipeCategory? {
        let hasDolce = domains.contains(.dolce)
        let hasSalato = domains.contains(.salato)
        if hasDolce && !hasSalato {
            return .dessert_al_cucchiaio
        }
        if hasSalato && !hasDolce {
            if domains.filter({ $0 == .salato }).count >= 2 { return .primo_piatto }
            return .secondo_piatto
        }
        if domains.allSatisfy({ $0 == .neutro }) {
            return .primo_piatto
        }
        return .primo_piatto
    }
    
    // MARK: - Pipeline pubblica
    
    /// Valida gli ingredienti e restituisce input pronto per l'AI oppure un rifiuto con motivo e alternative.
    static func validate(items: [FoodItem]) -> Result<ValidatedRecipeInput, RecipeRejection> {
        guard items.count >= 2 else {
            return .failure(RecipeRejection(
                reason: "Servono almeno due ingredienti per una ricetta.",
                alternatives: ["Aggiungi altri ingredienti dall'inventario."]
            ))
        }
        
        if let reject = checkStructuralRules(items: items) { return .failure(reject) }
        if let reject = checkHardRules(items: items) { return .failure(reject) }
        
        let domains = items.map { domain(for: $0) }
        guard let category = inferCategory(from: items, domains: domains) else {
            return .failure(RecipeRejection(
                reason: "Non è possibile determinare un tipo di ricetta coerente con questi ingredienti.",
                alternatives: ["Scegli ingredienti più omogenei (tutti dolci o tutti salati)."]
            ))
        }
        
        let domainForCategory: FoodFadeDomain = category.allowedDomain ?? .neutro
        let withRoles = assignRoles(items: items, domain: domainForCategory)
        
        return .success(ValidatedRecipeInput(category: category, items: withRoles, domain: domainForCategory))
    }
}
