import SwiftUI
import SwiftData

/// Vista per generare ricette basate sugli ingredienti disponibili
struct RecipesView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @StateObject private var viewModel = RecipesViewModel()
    @State private var selectedIngredients: Set<UUID> = []
    @State private var showingRecipe = false
    @State private var generatedRecipe: Recipe?
    
    private var availableItems: [FoodItem] {
        allItems.filter { !$0.isConsumed }
    }
    
    private var expiringItems: [FoodItem] {
        availableItems.filter { item in
            item.expirationStatus == .today || item.expirationStatus == .soon || item.expirationStatus == .expired
        }
    }
    
    private var otherItems: [FoodItem] {
        availableItems.filter { item in
            item.expirationStatus != .today && item.expirationStatus != .soon && item.expirationStatus != .expired
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isGenerating {
                    MagicLoadingView()
                        .transition(AnyTransition.opacity)
                } else if showingRecipe, let recipe = generatedRecipe {
                    recipeView(recipe: recipe)
                        .transition(AnyTransition.move(edge: .bottom).combined(with: .opacity))
                } else {
                    ingredientsSelectionView
                }
            }
            .navigationTitle("recipe.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedIngredients.isEmpty && !showingRecipe {
                        Button {
                            generateRecipe()
                        } label: {
                            Text("recipe.generate".localized)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(ThemeManager.shared.primaryColor)
                        }
                        .disabled(selectedIngredients.isEmpty || selectedIngredients.count > 6)
                    }
                }
            }
        }
    }
    
    // MARK: - Ingredients Selection View
    
    private var ingredientsSelectionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("recipe.select_up_to".localized(6))
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(.secondary)
                    
                    if !selectedIngredients.isEmpty {
                        Text("recipe.selected_count".localized(selectedIngredients.count, 6))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(ThemeManager.shared.primaryColor)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Ingredienti in scadenza
                if !expiringItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("recipe.expiring_section".localized, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.orange)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(expiringItems) { item in
                                IngredientCard(
                                    item: item,
                                    isSelected: selectedIngredients.contains(item.id),
                                    isExpiring: true
                                ) {
                                    toggleSelection(for: item)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Altri ingredienti
                if !otherItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("recipe.other_ingredients".localized, systemImage: "leaf.fill")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(otherItems) { item in
                                IngredientCard(
                                    item: item,
                                    isSelected: selectedIngredients.contains(item.id),
                                    isExpiring: false
                                ) {
                                    toggleSelection(for: item)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                
                // Empty state
                if availableItems.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Nessun ingrediente disponibile")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text("Aggiungi alcuni prodotti per generare ricette")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
                }
            }
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Recipe View
    
    private func recipeView(recipe: Recipe) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Se la ricetta non è fattibile, mostra messaggio
                if !recipe.feasible {
                    notFeasibleView(recipe: recipe)
                } else {
                    // Header ricetta
                    VStack(alignment: .leading, spacing: 12) {
                        if let title = recipe.title {
                            Text(title)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        if let description = recipe.description {
                            Text(description)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        // Tempi e porzioni
                        if recipe.prepTime != nil || recipe.cookTime != nil || recipe.servings != nil {
                            HStack(spacing: 16) {
                                if let prepTime = recipe.prepTime {
                                    Label(prepTime, systemImage: "clock")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                if let cookTime = recipe.cookTime {
                                    Label(cookTime, systemImage: "flame")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                if let servings = recipe.servings {
                                    Label(servings, systemImage: "person.2")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                
                    // Ingredienti selezionati
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ingredienti")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        ForEach(recipe.ingredients, id: \.self) { ingredient in
                            HStack(spacing: 12) {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundColor(ThemeManager.shared.primaryColor)
                                Text(ingredient)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Istruzioni
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Preparazione")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)
                        
                        ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 28, height: 28)
                                    .background(ThemeManager.shared.primaryColor)
                                    .clipShape(Circle())
                                
                                Text(instruction)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Pulsante per tornare
                    Button {
                        withAnimation {
                            showingRecipe = false
                            generatedRecipe = nil
                            selectedIngredients.removeAll()
                        }
                    } label: {
                        Text("Nuova Ricetta")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(ThemeManager.shared.primaryColor)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
            }
        }
    }
    
    // MARK: - Not Feasible View
    
    private func notFeasibleView(recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.orange)
                    Text("Ricetta non fattibile")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                
                if let reason = recipe.reason {
                    Text(reason)
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                if let alternatives = recipe.alternatives, !alternatives.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Alternative suggerite:")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        ForEach(alternatives, id: \.self) { alternative in
                            HStack(spacing: 12) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(ThemeManager.shared.primaryColor)
                                Text(alternative)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Pulsante per tornare
            Button {
                withAnimation {
                    showingRecipe = false
                    generatedRecipe = nil
                    selectedIngredients.removeAll()
                }
            } label: {
                Text("Prova con altri ingredienti")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(ThemeManager.shared.primaryColor)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Helper Functions
    
    private func toggleSelection(for item: FoodItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedIngredients.contains(item.id) {
                selectedIngredients.remove(item.id)
            } else {
                if selectedIngredients.count < 5 {
                    selectedIngredients.insert(item.id)
                }
            }
        }
    }
    
    private func generateRecipe() {
        let selectedItems = availableItems.filter { selectedIngredients.contains($0.id) }
        viewModel.generateRecipe(from: selectedItems) { recipe in
            withAnimation {
                generatedRecipe = recipe
                showingRecipe = true
            }
        }
    }
}

// MARK: - Ingredient Card

struct IngredientCard: View {
    let item: FoodItem
    let isSelected: Bool
    let isExpiring: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .white : ThemeManager.shared.primaryColor)
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
                
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                if isExpiring {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                        Text(item.daysRemaining == 1 ? "item.day".localized : String(format: "item.days".localized, item.daysRemaining))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .orange)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? ThemeManager.shared.primaryColor : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? ThemeManager.shared.primaryColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recipe Model

struct Recipe: Identifiable {
    let id = UUID()
    let feasible: Bool
    let title: String?
    let description: String?
    let ingredients: [String]
    let instructions: [String]
    let reason: String? // Per ricette non fattibili
    let alternatives: [String]? // Alternative suggerite
    let prepTime: String?
    let cookTime: String?
    let servings: String?
    
    // Inizializzatore per ricetta fattibile
    init(title: String, description: String?, ingredients: [String], instructions: [String], prepTime: String? = nil, cookTime: String? = nil, servings: String? = nil) {
        self.feasible = true
        self.title = title
        self.description = description
        self.ingredients = ingredients
        self.instructions = instructions
        self.reason = nil
        self.alternatives = nil
        self.prepTime = prepTime
        self.cookTime = cookTime
        self.servings = servings
    }
    
    // Inizializzatore per ricetta non fattibile
    init(reason: String, alternatives: [String]?) {
        self.feasible = false
        self.title = nil
        self.description = nil
        self.ingredients = []
        self.instructions = []
        self.reason = reason
        self.alternatives = alternatives
        self.prepTime = nil
        self.cookTime = nil
        self.servings = nil
    }
}

#Preview {
    RecipesView()
        .modelContainer(for: FoodItem.self, inMemory: true)
}
