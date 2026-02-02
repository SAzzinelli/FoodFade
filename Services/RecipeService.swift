import Foundation
import SwiftData

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Protocollo per il servizio di generazione ricette
protocol RecipeService {
    func generateRecipe(from items: [FoodItem]) async throws -> Recipe
}

/// Implementazione con Apple Intelligence
@MainActor
class RecipeServiceImpl: RecipeService {
    static let shared = RecipeServiceImpl()
    
    private let isAppleIntelligenceAvailable: Bool
    
    private init() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, macOS 26.0, *) {
            isAppleIntelligenceAvailable = true
        } else {
            isAppleIntelligenceAvailable = false
        }
        #else
        isAppleIntelligenceAvailable = false
        #endif
    }
    
    func generateRecipe(from items: [FoodItem]) async throws -> Recipe {
        guard isAppleIntelligenceAvailable && IntelligenceManager.shared.isFridgyAvailable else {
            throw RecipeError.appleIntelligenceNotAvailable
        }
        
        // 1. Validazione FoodFade: regole HARD prima di chiamare l'AI
        switch FoodFadeCulinaryLogic.validate(items: items) {
        case .failure(let rejection):
            return Recipe(reason: rejection.reason, alternatives: rejection.alternatives)
        case .success(let validated):
            return try await generateWithAppleIntelligence(validated: validated)
        }
    }
    
    /// System prompt FoodFade: l'AI scrive solo dentro un mondo realistico
    private static let foodFadeSystemPrompt = """
    You are Foodfade AI.
    Your task is to write a realistic, human, and culturally plausible recipe.
    
    IMPORTANT RULES (MANDATORY):
    - You MUST use ONLY the ingredients provided.
    - You MUST respect the recipe category and its culinary domain.
    - You MUST NOT invent, replace, or add ingredients.
    - The recipe MUST be something a real human could cook today in a normal kitchen.
    - Avoid experimental, abstract, or shocking combinations.
    - The result must feel natural, believable, and edible.
    
    Culinary constraints:
    - All ingredients are already compatible: do not question them.
    - Do not mix sweet and savory logic.
    - Cooking times and techniques must be realistic.
    - Use simple, clear steps.
    
    Tone:
    - Warm, human, confident
    - No poetic exaggerations
    - No AI disclaimers
    - No unnecessary creativity
    
    If something feels unnatural or forced, simplify it.
    Your goal is credibility, not originality.
    
    Respond ONLY with valid JSON. If feasible: {"feasible": true, "title": "...", "description": "...", "ingredients": [...], "instructions": [...], "prepTime": "...", "cookTime": "...", "servings": "..."}
    If not feasible: {"feasible": false, "reason": "...", "alternatives": [...]}
    """
    
    @available(iOS 26.0, macOS 26.0, *)
    private func generateWithAppleIntelligence(validated: ValidatedRecipeInput) async throws -> Recipe {
        #if canImport(FoundationModels)
        let ingredientsList = validated.items.map { pair in
            "\(pair.item.name) (\(pair.role.rawValue))"
        }.joined(separator: ", ")
        
        let categoryName = validated.category.displayName
        let domainName = validated.domain.rawValue
        
        let prompt = """
        Categoria ricetta: \(categoryName)
        Dominio: \(domainName)
        
        Ingredienti da usare (SOLO questi, con il ruolo indicato):
        \(ingredientsList)
        
        Scrivi una ricetta fattibile, realistica e culturalmente plausibile.
        Max 6 ingredienti nella lista finale, max 8 passi.
        Rispondi SOLO con JSON valido: {"feasible": true, "title": "...", "description": "...", "ingredients": [...], "instructions": [...], "prepTime": "...", "cookTime": "...", "servings": "..."}
        """
        
        let model = SystemLanguageModel.default
        
        guard case .available = model.availability else {
            throw RecipeError.appleIntelligenceNotAvailable
        }
        
        let session = LanguageModelSession(instructions: Self.foodFadeSystemPrompt)
        let response = try await session.respond(to: prompt)
        
        let text = response.content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return try parseRecipeResponse(text: text)
        #else
        throw RecipeError.appleIntelligenceNotAvailable
        #endif
    }
    
    private func parseRecipeResponse(text: String) throws -> Recipe {
        // Estrai JSON dalla risposta
        let jsonString = extractJSON(from: text)
        
        // Pulisci il JSON da eventuali markdown o code blocks
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        guard let jsonData = cleanedJSON.data(using: String.Encoding.utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            print("Errore parsing JSON: \(cleanedJSON)")
            throw RecipeError.invalidResponse
        }
        
        // Controlla se la ricetta è fattibile
        if let feasible = json["feasible"] as? Bool, !feasible {
            // Ricetta non fattibile
            let reason = (json["reason"] as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? "Questa combinazione di ingredienti non è adatta per una ricetta."
            let alternatives = (json["alternatives"] as? [String])?.map { sanitizeText($0) }
            
            return Recipe(reason: sanitizeText(reason), alternatives: alternatives)
        }
        
        // Ricetta fattibile - valida i campi obbligatori
        guard let title = json["title"] as? String,
              let ingredients = json["ingredients"] as? [String],
              !ingredients.isEmpty,
              let instructions = json["instructions"] as? [String],
              !instructions.isEmpty else {
            print("Errore: campi obbligatori mancanti nel JSON")
            throw RecipeError.invalidResponse
        }
        
        let titleString = title.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !titleString.isEmpty else {
            print("Errore: titolo vuoto dopo trimming")
            throw RecipeError.invalidResponse
        }
        
        let description = (json["description"] as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let prepTime = (json["prepTime"] as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let cookTime = (json["cookTime"] as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let servings = (json["servings"] as? String)?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Valida che il contenuto sia sicuro
        let safeTitle = sanitizeText(titleString)
        let safeDescription = description.map { sanitizeText($0) }
        let safeIngredients = ingredients.map { sanitizeText($0) }
        let safeInstructions = instructions.map { sanitizeText($0) }
        let safePrepTime = prepTime.map { sanitizeText($0) }
        let safeCookTime = cookTime.map { sanitizeText($0) }
        let safeServings = servings.map { sanitizeText($0) }
        
        return Recipe(
            title: safeTitle,
            description: safeDescription,
            ingredients: safeIngredients,
            instructions: safeInstructions,
            prepTime: safePrepTime,
            cookTime: safeCookTime,
            servings: safeServings
        )
    }
    
    private func extractJSON(from text: String) -> String {
        // Cerca il primo { e l'ultimo }
        if let startIndex = text.firstIndex(of: "{"),
           let endIndex = text.lastIndex(of: "}") {
            return String(text[startIndex...endIndex])
        }
        return text
    }
    
    private func sanitizeText(_ text: String) -> String {
        // Rimuovi caratteri problematici e normalizza il testo
        var sanitized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Limita la lunghezza per sicurezza
        if sanitized.count > 200 {
            sanitized = String(sanitized.prefix(200))
        }
        
        return sanitized
    }
}

enum RecipeError: LocalizedError {
    case appleIntelligenceNotAvailable
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .appleIntelligenceNotAvailable:
            return "Apple Intelligence non disponibile"
        case .invalidResponse:
            return "Risposta non valida dal modello"
        }
    }
}
