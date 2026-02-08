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
    
    private var filteredItems: [FoodItem] {
        viewModel.items.filter { !$0.isConsumed }
    }
    
    private var accentColor: Color {
        ThemeManager.shared.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Barra ricerca
                searchSection
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(.systemGroupedBackground))
                
                // Filtri categoria
                filterSection
                
                // Lista items
                if filteredItems.isEmpty {
                    emptyState
                } else {
                    listSection
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("nav.inventory".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
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
            .sheet(isPresented: $showingAddFood) {
                AddFoodView()
            }
            .sheet(item: $selectedItem) { item in
                NavigationStack {
                    ItemDetailView(item: item)
                }
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
                if let category = categoryFilter {
                    selectedCategory = category
                    viewModel.selectedCategory = category
                } else {
                    selectedCategory = nil
                    viewModel.selectedCategory = nil
                }
                viewModel.filterStatus = filterStatus
                viewModel.loadData()
            }
            .tint(ThemeManager.shared.primaryColor)
            .onChange(of: selectedCategory) { _, newValue in
                viewModel.selectedCategory = newValue
                viewModel.filterStatus = filterStatus
                viewModel.loadData()
            }
            .onChange(of: searchText) { _, newValue in
                viewModel.searchText = newValue
                viewModel.filterStatus = filterStatus
                viewModel.loadData()
            }
            .onChange(of: allItems.count) { _, _ in
                viewModel.filterStatus = filterStatus
                viewModel.loadData()
            }
        }
    }
    
    // MARK: - Search
    private var searchSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))
            TextField("inventory.search.prompt".localized, text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.tertiarySystemFill))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    // MARK: - Filtri categoria (chip scorrevoli)
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                CategoryFilterButton(
                    title: "common.all".localized,
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color: accentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) {
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
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Lista
    private var listSection: some View {
        List {
            ForEach(filteredItems) { item in
                FoodItemRow(
                    item: item,
                    onConsume: { viewModel.markAsConsumed(item) },
                    onEdit: { selectedItem = item },
                    onDelete: { viewModel.deleteItem(item) }
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button {
                        viewModel.markAsConsumed(item)
                    } label: {
                        Label("inventory.consumed".localized, systemImage: "checkmark.circle.fill")
                    }
                    .tint(.green)
                    Button(role: .destructive) {
                        viewModel.deleteItem(item)
                    } label: {
                        Label("common.delete".localized, systemImage: "trash.fill")
                    }
                    .tint(.red)
                }
                .swipeActions(edge: .leading, allowsFullSwipe: false) {
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
    
    // MARK: - Empty state
    private var emptyStateButtonColor: Color {
        if let category = selectedCategory {
            return AppTheme.color(for: category)
        }
        return ThemeManager.shared.onboardingButtonColor
    }
    
    private var emptyState: some View {
        let isCategoryFilter = categoryFilter != nil
        return VStack(spacing: 20) {
            Spacer()
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            if searchText.isEmpty {
                if isCategoryFilter {
                    Text("inventory.category.empty".localized)
                        .font(.system(size: 18, weight: .semibold, design: .default))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
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
                            .foregroundStyle(.white)
                            .frame(maxWidth: 200)
                            .frame(height: 50)
                            .background(emptyStateButtonColor)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .tint(.white)
                }
            } else {
                Text("inventory.search.empty.title".localized)
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                Text("inventory.search.empty.subtitle".localized(searchText))
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
        .background(Color(.systemGroupedBackground))
    }
}

// MARK: - Pulsante filtro categoria (chip)
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
