import SwiftUI
import SwiftData

/// Vista dedicata per i prodotti "In scadenza" (status .soon – scadono a breve)
struct ExpiringSoonView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showFridgyBravo = false
    
    private var expiringSoonItems: [FoodItem] {
        allItems.filter { item in
            !item.isConsumed && item.expirationStatus == .soon
        }
        .sorted { item1, item2 in
            item1.daysRemaining < item2.daysRemaining
        }
    }
    
    var body: some View {
        Group {
            if expiringSoonItems.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Nessun prodotto in scadenza")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Non ci sono prodotti che scadono a breve")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 40)
                .padding(.vertical, 20)
                .background(Color(.systemGroupedBackground))
            } else {
                List {
                    ForEach(expiringSoonItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            ExpiringSoonCard(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                item.isConsumed = true
                                item.consumedDate = Date()
                                item.lastUpdated = Date()
                                try? modelContext.save()
                                showFridgyBravo = true
                            } label: {
                                Label("Consumato", systemImage: "checkmark.circle.fill")
                            }
                            .tint(.green)
                            
                            Button(role: .destructive) {
                                modelContext.delete(item)
                                try? modelContext.save()
                            } label: {
                                Label("Elimina", systemImage: "trash.fill")
                            }
                            .tint(.red)
                        }
                    }
                }
            }
        }
        .overlay {
            if showFridgyBravo {
                FridgyBravoOverlay { showFridgyBravo = false }
            }
        }
        .navigationTitle("In scadenza")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Card (stile uniforme a ExpiringTodayCard / ToConsumeCard)
private struct ExpiringSoonCard: View {
    let item: FoodItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.iconFill)
                .font(.system(size: 24))
                .foregroundColor(categoryColor)
                .frame(width: 40, height: 40)
                .background(categoryColor.opacity(0.1))
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Label(item.effectiveExpirationDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text(daysText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.orange)
                    
                    Text("·")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Qtà. \(item.quantity)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var daysText: String {
        if item.daysRemaining == 1 {
            return "Tra 1 giorno"
        }
        return "Tra \(item.daysRemaining) giorni"
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
