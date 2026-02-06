import SwiftUI
import SwiftData

/// Vista dedicata per i prodotti prossimi alla scadenza
struct ExpiringSoonView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared
    
    private var expiringSoonItems: [FoodItem] {
        allItems.filter { item in
            !item.isConsumed && item.expirationStatus == .soon
        }
        .sorted { item1, item2 in
            item1.daysRemaining < item2.daysRemaining
        }
    }
    
    var body: some View {
        ScrollView {
            if expiringSoonItems.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(expiringSoonItems) { item in
                        ExpiringSoonItemCard(item: item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Prossimi alla Scadenza")
        .navigationBarTitleDisplayMode(.large)
        .tint(themeManager.primaryColor)
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Nessun prodotto in scadenza")
                .font(.system(size: 22, weight: .semibold, design: .default))
                .foregroundColor(.primary)
            
            Text("Non ci sono prodotti che scadono a breve")
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

// MARK: - Expiring Soon Item Card
private struct ExpiringSoonItemCard: View {
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
                    Text("Qtà. \(item.quantity)")
                    Text("•")
                        .foregroundColor(.secondary)
                    Label(item.category.rawValue, systemImage: item.category.icon)
                }
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.system(size: 12))
                    Text("Scade il \(item.expirationDate.formatted(date: .abbreviated, time: .omitted))")
                        .font(.system(size: 14, weight: .medium, design: .default))
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Tra \(item.daysRemaining) \(item.daysRemaining == 1 ? "giorno" : "giorni")")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                }
                .foregroundColor(.yellow)
            }
            
            Spacer()
            
            // Countdown badge
            VStack {
                Text("\(item.daysRemaining)")
                    .font(.system(size: 20, weight: .bold, design: .default))
                    .foregroundColor(.white)
                Text(item.daysRemaining == 1 ? "giorno" : "giorni")
                    .font(.system(size: 10, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.9))
            }
            .frame(width: 50, height: 50)
            .background(
                LinearGradient(
                    colors: [Color.yellow, Color.orange.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .cornerRadius(12)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 2)
        )
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
        ExpiringSoonView()
            .modelContainer(for: FoodItem.self, inMemory: true)
    }
}

