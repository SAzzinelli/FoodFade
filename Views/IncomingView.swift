import SwiftUI
import SwiftData

/// Vista dedicata per "Nei prossimi giorni" (scadono tra 2-3 giorni)
struct IncomingView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showFridgyBravo = false
    
    private var incomingItems: [FoodItem] {
        let calendar = Calendar.current
        let now = Date()
        let endOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 2, to: now) ?? now)
        let soonThreshold = calendar.date(byAdding: .day, value: 3, to: now) ?? now
        
        return allItems.filter { item in
            guard !item.isConsumed else { return false }
            let expiry = item.effectiveExpirationDate
            // Solo quelli che scadono dopo domani ma entro 3 giorni
            return expiry > endOfTomorrow && expiry <= soonThreshold
        }
    }
    
    var body: some View {
        Group {
            if incomingItems.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "clock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("Nessun prodotto in scadenza")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("I prodotti che scadono nei prossimi giorni appariranno qui")
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
                    ForEach(incomingItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            IncomingCard(item: item)
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
        .navigationTitle("Nei prossimi giorni")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct IncomingCard: View {
    let item: FoodItem
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = item.photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else {
                    Image(systemName: item.category.iconFill)
                        .font(.system(size: 24))
                        .foregroundColor(categoryColor)
                }
            }
            .frame(width: 40, height: 40)
            .background(categoryColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 8) {
                    Label(item.effectiveExpirationDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Text("\(item.daysRemaining) \(item.daysRemaining == 1 ? "giorno" : "giorni")")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.yellow)
                    
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
    
    var categoryColor: Color {
        switch item.category {
        case .fridge: return .blue
        case .freezer: return .cyan
        case .pantry: return .orange
        }
    }
}

#Preview {
    IncomingView()
        .modelContainer(for: FoodItem.self)
}

