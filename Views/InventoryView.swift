import SwiftUI
import SwiftData

/// Vista dell'inventario con filtri e ricerca
struct InventoryView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @StateObject private var viewModel = InventoryViewModel()
    @State private var searchText = ""
    @State private var selectedCategory: FoodCategory? = nil
    @State private var selectedItem: FoodItem?
    @State private var showingAddFood = false
    
    let filterStatus: ExpirationStatus?
    let categoryFilter: FoodCategory?
    
    init(filterStatus: ExpirationStatus? = nil, categoryFilter: FoodCategory? = nil) {
        self.filterStatus = filterStatus
        self.categoryFilter = categoryFilter
    }
    
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filtri categoria
                categoryFilterView
                    .padding(.vertical, 12)
                    .background(Color(.systemGroupedBackground))
                
                Divider()
                
                // Lista items
                if viewModel.items.filter({ !$0.isConsumed }).isEmpty {
                    emptyState
                } else {
                    listView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("nav.inventory".localized)
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundColor(ThemeManager.shared.primaryColor)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddFood = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(ThemeManager.shared.primaryColor)
                    }
                    .accessibilityLabel("common.add".localized)
                }
            }
            .searchable(text: $searchText, prompt: "inventory.search.prompt".localized)
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
            .sheet(item: $selectedItem) { item in
                ItemDetailView(item: item)
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
                if let category = categoryFilter {
                    selectedCategory = category
                    viewModel.selectedCategory = category
                } else {
                    // Reset categoria se non c'è un filtro iniziale
                    selectedCategory = nil
                    viewModel.selectedCategory = nil
                }
                // Imposta il filtro status prima di caricare i dati
                viewModel.filterStatus = filterStatus
                viewModel.loadData()
            }
            .tint(ThemeManager.shared.primaryColor)
            .onChange(of: selectedCategory) { oldValue, newValue in
                viewModel.selectedCategory = newValue
                viewModel.filterStatus = filterStatus
                viewModel.loadData()
            }
            .onChange(of: searchText) { oldValue, newValue in
                viewModel.searchText = newValue
                viewModel.filterStatus = filterStatus // Mantieni il filtro status
                viewModel.loadData()
            }
            .onChange(of: allItems.count) { oldValue, newValue in
                // Mantieni il filtro quando i dati vengono ricaricati
                viewModel.filterStatus = filterStatus
                viewModel.loadData()
            }
            .onChange(of: viewModel.sortAscending) { oldValue, newValue in
                viewModel.loadData()
            }
        }
    }
    
    private var categoryFilterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryFilterButton(
                    title: "common.all".localized,
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color: ThemeManager.shared.primaryColor
                ) {
                    withAnimation {
                        selectedCategory = nil
                    }
                }
                
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    CategoryFilterButton(
                        title: category.rawValue,
                        icon: category.iconFill,
                        isSelected: selectedCategory == category,
                        color: AppTheme.color(for: category)
                    ) {
                        withAnimation {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private var listView: some View {
        List {
            ForEach(viewModel.items.filter { !$0.isConsumed }) { item in
                FoodItemRow(
                    item: item,
                    onConsume: {
                        viewModel.markAsConsumed(item)
                    },
                    onEdit: {
                        selectedItem = item
                    },
                    onDelete: {
                        viewModel.deleteItem(item)
                    }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    // Azione principale: Consuma (swipe completo)
                    Button {
                        viewModel.markAsConsumed(item)
                    } label: {
                        Label("inventory.consumed".localized, systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)
                    
                    // Azione secondaria: Elimina (sempre sfondo rosso)
                    Button(role: .destructive) {
                        viewModel.deleteItem(item)
                    } label: {
                        Label("common.delete".localized, systemImage: "trash.fill")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                    // Azione sinistra: Modifica
                    Button {
                        selectedItem = item
                    } label: {
                        Label("common.edit".localized, systemImage: "pencil")
                    }
                    .tint(.blue)
                }
                .onTapGesture {
                    selectedItem = item
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("inventory.empty.title".localized)
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundColor(.primary)
            
            Text("inventory.empty.subtitle".localized)
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            
            Button {
                showingAddFood = true
            } label: {
                Text("inventory.empty.button".localized)
                    .font(.system(size: 17, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .frame(height: 50)
                    .background(ThemeManager.shared.primaryColor)
                    .cornerRadius(12)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(Color(.systemGroupedBackground))
    }
    
    private func filterByStatus(_ status: ExpirationStatus) {
        // Il filtro viene applicato nel ViewModel
    }
}

// MARK: - Category Filter Button
private struct CategoryFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular, design: .default))
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? color : Color(.secondarySystemGroupedBackground))
            .cornerRadius(20)
        }
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#Preview {
    InventoryView(filterStatus: nil)
        .modelContainer(for: FoodItem.self)
}
