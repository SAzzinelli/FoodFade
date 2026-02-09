import Foundation
import SwiftData

/// Esito della validazione culinaria pre-AI: rifiuto con motivo e alternative
struct RecipeValidationRejection: Error {
    let reason: String
    let alternatives: [String]?
}

/// Ruolo dell'ingredient nella ricetta (per prompt AI)
enum IngredientRole: String {
    case main = "principale"
    case side = "secondario"
    case seasoning = "condimento"
}

/// Dominio culinario: dolce vs salato (no mix nelle ricette FoodFade)
enum RecipeDomain: String {
    case sweet = "dolce"
    case savory = "salato"
}

/// Categoria ricetta per il prompt (display per l'AI)
struct RecipeCategoryForValidation {
    let displayName: String
}

/// Input validato da passare all'AI: ingredienti con ruoli, categoria e dominio
struct ValidatedRecipeInput {
    let items: [(item: FoodItem, role: IngredientRole)]
    let category: RecipeCategoryForValidation
    let domain: RecipeDomain
}

/// Regole HARD pre-AI: coerenza dolce/salato, niente abbinamenti assurdi (biscotti + pomodoro, etc.)
enum FoodFadeCulinaryLogic {
    
    private static let sweetKeywords: Set<String> = [
        "biscotto", "biscotti", "cioccolato", "miele", "marmellata", "marmellata",
        "cracker", "cereali", "barretta", "barrette", "dolce", "torta", "croissant",
        "nutella", "crema", "zucchero", "colazione", "fetta", "brioche", "merenda"
    ]
    
    private static let savoryKeywords: Set<String> = [
        "pomodoro", "pasta", "riso", "carne", "pesce", "brodo", "sugo", "sale",
        "insalata", "formaggio", "salume", "pane", "olio", "legum", "zuppa",
        "verdura", "frutta" // frutta in contesto ricetta spesso salato (insalata)
    ]
    
    /// Classifica l'ingredient come dolce o salato (euristica sul nome)
    private static func domain(for item: FoodItem) -> RecipeDomain {
        let name = item.name.lowercased()
        if sweetKeywords.contains(where: { name.contains($0) }) {
            return .sweet
        }
        if savoryKeywords.contains(where: { name.contains($0) }) {
            return .savory
        }
        return .savory // default: salato
    }
    
    /// Valida gli ingredienti prima di chiamare l'AI: niente mix dolce/salato assurdo
    static func validate(items: [FoodItem]) -> Result<ValidatedRecipeInput, RecipeValidationRejection> {
        guard items.count >= 1, items.count <= 6 else {
            return .failure(RecipeValidationRejection(
                reason: items.isEmpty ? "Seleziona almeno un ingrediente." : "Troppi ingredienti (max 6).",
                alternatives: nil
            ))
        }
        
        let domains = items.map { Self.domain(for: $0) }
        let hasSweet = domains.contains(RecipeDomain.sweet)
        let hasSavory = domains.contains(RecipeDomain.savory)
        
        // HARD: non mescolare dolce e salato (biscotti + pomodoro, etc.)
        if hasSweet && hasSavory {
            return .failure(RecipeValidationRejection(
                reason: "Questa combinazione mescola ingredienti dolci e salati. Scegli solo ingredienti dello stesso tipo.",
                alternatives: ["Scegli solo ingredienti dolci per un dessert.", "Scegli solo ingredienti salati per un piatto unico."]
            ))
        }
        
        let recipeDomain: RecipeDomain = hasSweet ? .sweet : .savory
        let categoryName = recipeDomain == .sweet ? "Dessert / Colazione" : "Piatto unico"
        let validated = ValidatedRecipeInput(
            items: items.map { ($0, IngredientRole.main) },
            category: RecipeCategoryForValidation(displayName: categoryName),
            domain: recipeDomain
        )
        return .success(validated)
    }
}
