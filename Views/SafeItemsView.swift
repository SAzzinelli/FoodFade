import SwiftUI
import SwiftData

/// Vista dedicata per i prodotti sicuri
struct SafeItemsView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared
    
    private var safeItems: [FoodItem] {
        allItems.filter { item in
            !item.isConsumed && item.expirationStatus == .safe
        }
    }
    
    var body: some View {
        ScrollView {
            if safeItems.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(safeItems) { item in
                        SafeItemCard(item: item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Prodotti Sicuri")
        .navigationBarTitleDisplayMode(.large)
        .tint(themeManager.primaryColor)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Nessun prodotto sicuro")
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundColor(.primary)
            
            Text("I prodotti sicuri sono quelli con scadenza lontana")
                .font(.system(size: 16, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
}

// MARK: - Safe Item Card
private struct SafeItemCard: View {
    let item: FoodItem
    @StateObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Icona categoria
            Image(systemName: item.category.icon)
                .font(.system(size: 32))
                .foregroundColor(categoryColor)
                .frame(width: 60, height: 60)
                .background(categoryColor.opacity(0.15))
                .cornerRadius(12)
            
            // Informazioni principali
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    Label("\(item.daysRemaining) \(item.daysRemaining == 1 ? "giorno" : "giorni")", systemImage: "calendar")
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Qtà. \(item.quantity)")
                }
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                
                Text("Scade il \(item.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.green)
            }
            
            Spacer()
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
    
    var categoryColor: Color {
        switch item.category {
        case .fridge: return .blue
        case .freezer: return .cyan
        case .pantry: return .orange
        }
    }
}

#Preview {
    NavigationStack {
        SafeItemsView()
            .modelContainer(for: FoodItem.self, inMemory: true)
    }
}

