import SwiftUI
import SwiftData

/// Vista inventario "In casa" – ridisegnata da zero
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
            Group {
                if filteredItems.isEmpty {
                    ScrollView {
                        VStack(spacing: 20) {
                            categoryPills
                            emptyContent
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 24)
                        .padding(.bottom, 32)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 12) {
                        categoryPills
                        if selectedCategory != nil {
                            Text(String(format: "inventory.results.count".localized, filteredItems.count))
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        List {
                            Section {
                                ForEach(filteredItems) { item in
                                InventoryCard(
                                    item: item,
                                    onTap: { selectedItem = item },
                                    onConsume: { viewModel.markAsConsumed(item) },
                                    onEdit: { selectedItem = item },
                                    onDelete: { viewModel.deleteItem(item) }
                                )
                                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color(.systemGroupedBackground))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        viewModel.deleteItem(item)
                                    } label: { Label("common.delete".localized, systemImage: "trash") }
                                    .tint(.red)
                                    Button {
                                        selectedItem = item
                                    } label: { Label("common.edit".localized, systemImage: "pencil") }
                                    .tint(ThemeManager.shared.isNaturalStyle ? Color(.tertiaryLabel) : ThemeManager.shared.primaryColor)
                                }
                            }
                        }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color(.systemGroupedBackground))
                        .contentMargins(.top, AppTheme.spacingBelowLargeTitle, for: .scrollContent)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .searchable(text: $searchText, prompt: Text("inventory.search.prompt".localized))
            .background(Color(.systemGroupedBackground))
            .navigationTitle("nav.inventory".localized)
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .bottom) {
                Text(String(format: "inventory.total_items".localized, filteredItems.count))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingAddFood = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.tint(ThemeManager.shared.isNaturalStyle ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor).interactive(), in: .circle)
                .padding(.trailing, 20)
                .padding(.bottom, 18)
                .accessibilityLabel("common.add".localized)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(ThemeManager.naturalHomeLogoColor)
                        Text("FoodFade")
                            .font(.system(size: 20, weight: .bold, design: .default))
                            .foregroundColor(ThemeManager.naturalHomeLogoColor)
                    }
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
            .tint(ThemeManager.shared.primaryColor)
        }
    }
    
    // MARK: - Filtri categoria
    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                InventoryFilterPill(
                    title: "common.all".localized,
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil,
                    color: accentColor
                ) {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = nil }
                }
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    InventoryFilterPill(
                        title: category.rawValue,
                        icon: category.iconFill,
                        isSelected: selectedCategory == category,
                        color: AppTheme.color(for: category)
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedCategory = category }
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    // MARK: - Empty state
    private var emptyContent: some View {
        let isCategoryFilter = categoryFilter != nil
        return VStack(spacing: 24) {
            Spacer(minLength: 40)
            Image(systemName: searchText.isEmpty ? "tray.fill" : "magnifyingglass")
                .font(.system(size: 56))
                .foregroundStyle(.secondary.opacity(0.8))
            if searchText.isEmpty {
                if isCategoryFilter {
                    Text("inventory.category.empty".localized)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                } else {
                    Text("inventory.empty.title".localized)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("inventory.empty.subtitle".localized)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Button {
                        showingAddFood = true
                    } label: {
                        Text("inventory.empty.button".localized)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(selectedCategory.map { AppTheme.color(for: $0) } ?? accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)
                }
            } else {
                Text("inventory.search.empty.title".localized)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)
                Text(String(format: "inventory.search.empty.subtitle".localized, searchText))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Pill filtro categoria
private struct InventoryFilterPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(isSelected ? color : Color(.tertiarySystemFill))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card singolo item (nuovo design)
private struct InventoryCard: View {
    let item: FoodItem
    let onTap: () -> Void
    let onConsume: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    private var categoryColor: Color {
        AppTheme.color(for: item.category)
    }
    
    private var statusColor: Color {
        switch item.expirationStatus {
        case .expired: return .red
        case .today: return .orange
        case .soon: return .orange
        case .safe: return .green
        }
    }
    
    private var daysText: String {
        item.daysRemaining == 1 ? "item.day".localized : String(format: "item.days".localized, item.daysRemaining)
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Thumbnail: foto o icona categoria
                ZStack {
                    if let data = item.photoData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: item.category.iconFill)
                            .font(.system(size: 22))
                            .foregroundStyle(categoryColor)
                    }
                }
                .frame(width: 52, height: 52)
                .background(categoryColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Nome + sottotitolo
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11))
                        Text(daysText)
                            .font(.system(size: 13))
                        Text("·")
                        Text("Qtà \(item.quantity)")
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Badge stato
                Text(item.expirationStatus.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor)
                    .clipShape(Capsule())
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(action: onConsume) {
                Label("inventory.mark.consumed".localized, systemImage: "checkmark.circle")
            }
            Button(action: onEdit) {
                Label("common.edit".localized, systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive, action: onDelete) {
                Label("common.delete".localized, systemImage: "trash")
            }
        }
        .accessibilityLabel("\(item.name), \(daysText), \(item.expirationStatus.rawValue)")
        .accessibilityHint("item.accessibility.hint".localized)
    }
}

#Preview {
    InventoryView(filterStatus: nil)
        .modelContainer(for: FoodItem.self)
}
