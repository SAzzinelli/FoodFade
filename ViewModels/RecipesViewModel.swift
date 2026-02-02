import Foundation
import SwiftData
import SwiftUI
import Combine

@MainActor
class RecipesViewModel: ObservableObject {
    @Published var isGenerating = false
    
    private let recipeService: RecipeService = RecipeServiceImpl.shared
    
    func generateRecipe(from items: [FoodItem], completion: @escaping (Recipe?) -> Void) {
        guard !items.isEmpty, items.count <= 5 else {
            completion(nil)
            return
        }
        
        isGenerating = true
        
        Task {
            do {
                let recipe = try await recipeService.generateRecipe(from: items)
                await MainActor.run {
                    isGenerating = false
                    completion(recipe)
                }
            } catch {
                print("Errore nella generazione della ricetta: \(error.localizedDescription)")
                await MainActor.run {
                    isGenerating = false
                    completion(nil)
                }
            }
        }
    }
}
