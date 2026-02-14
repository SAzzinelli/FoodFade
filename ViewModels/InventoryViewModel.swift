import Foundation
import SwiftData
import Combine

/// Tipo di ordinamento per l'inventario
enum InventorySortOption: String, CaseIterable {
    case expirationDate
    case name
    case category
    case quantity
    case createdAt
    case price
    
    var localizationKey: String {
        switch self {
        case .expirationDate: return "inventory.sort.expiration"
        case .name: return "inventory.sort.name_az"
        case .category: return "inventory.sort.category"
        case .quantity: return "inventory.sort.quantity"
        case .createdAt: return "inventory.sort.added"
        case .price: return "inventory.sort.price"
        }
    }
}

@MainActor
class InventoryViewModel: ObservableObject {
    @Published var selectedCategory: FoodCategory? = nil
    @Published var searchText: String = ""
    @Published var items: [FoodItem] = []
    @Published var isLoading = false
    @Published var sortOption: InventorySortOption = .expirationDate
    @Published var sortAscending: Bool = true
    
    var filterStatus: ExpirationStatus? = nil
    
    private var modelContext: ModelContext?
    
    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadData()
    }
    
    func loadData() {
        guard let modelContext = modelContext else { return }
        
        isLoading = true
        
        let descriptor = FetchDescriptor<FoodItem>(
            sortBy: [SortDescriptor(\.expirationDate, order: .forward)]
        )
        
        do {
            var fetchedItems = try modelContext.fetch(descriptor)
            
            // Filtra sempre gli item non consumati PRIMA di tutto
            fetchedItems = fetchedItems.filter { !$0.isConsumed }
            
            // Filtro per categoria se selezionata (dopo il fetch per evitare problemi con predicate)
            if let category = selectedCategory {
                fetchedItems = fetchedItems.filter { $0.category == category }
            }
            
            // Filtro per ricerca testo
            if !searchText.isEmpty {
                fetchedItems = fetchedItems.filter { item in
                    item.name.localizedCaseInsensitiveContains(searchText)
                }
            }
            
            // Filtro per status di scadenza (se specificato)
            if let status = filterStatus {
                fetchedItems = fetchedItems.filter { item in
                    if status == .today {
                        return item.expirationStatus == .expired || item.expirationStatus == .today
                    } else {
                        return item.expirationStatus == status
                    }
                }
            }
            
            // Ordina i risultati
            fetchedItems = sortItems(fetchedItems)
            
            items = fetchedItems
            isLoading = false
        } catch {
            print("Errore nel caricamento dell'inventario: \(error)")
            isLoading = false
        }
    }
    
    func deleteItem(_ item: FoodItem) {
        guard let modelContext = modelContext else { return }
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            loadData()
        } catch {
            print("Errore nell'eliminazione: \(error)")
        }
    }
    
    func markAsConsumed(_ item: FoodItem) {
        item.isConsumed = true
        item.consumedDate = Date()
        item.lastUpdated = Date()
        
        guard let modelContext = modelContext else { return }
        do {
            try modelContext.save()
            loadData()
        } catch {
            print("Errore nell'aggiornamento: \(error)")
        }
    }
    
    /// Ordina gli item in base all'opzione selezionata
    private func sortItems(_ items: [FoodItem]) -> [FoodItem] {
        let sorted: [FoodItem]
        
        switch sortOption {
        case .expirationDate:
            sorted = items.sorted { item1, item2 in
                let date1 = item1.effectiveExpirationDate
                let date2 = item2.effectiveExpirationDate
                return sortAscending ? date1 < date2 : date1 > date2
            }
        case .name:
            sorted = items.sorted { item1, item2 in
                let name1 = item1.name.lowercased()
                let name2 = item2.name.lowercased()
                return sortAscending ? name1 < name2 : name1 > name2
            }
        case .category:
            sorted = items.sorted { item1, item2 in
                let cat1 = item1.category.rawValue
                let cat2 = item2.category.rawValue
                if cat1 == cat2 {
                    // Se stessa categoria, ordina per data
                    return sortAscending ? item1.effectiveExpirationDate < item2.effectiveExpirationDate : item1.effectiveExpirationDate > item2.effectiveExpirationDate
                }
                return sortAscending ? cat1 < cat2 : cat1 > cat2
            }
        case .quantity:
            sorted = items.sorted { item1, item2 in
                return sortAscending ? item1.quantity < item2.quantity : item1.quantity > item2.quantity
            }
        case .createdAt:
            sorted = items.sorted { item1, item2 in
                return sortAscending ? item1.createdAt < item2.createdAt : item1.createdAt > item2.createdAt
            }
        case .price:
            sorted = items.sorted { item1, item2 in
                let p1 = item1.price ?? .greatestFiniteMagnitude
                let p2 = item2.price ?? .greatestFiniteMagnitude
                // Senza prezzo in fondo
                if p1 == .greatestFiniteMagnitude && p2 == .greatestFiniteMagnitude { return item1.name < item2.name }
                if p1 == .greatestFiniteMagnitude { return false }
                if p2 == .greatestFiniteMagnitude { return true }
                return sortAscending ? p1 < p2 : p1 > p2
            }
        }
        
        return sorted
    }
}

