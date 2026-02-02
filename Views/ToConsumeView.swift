import SwiftUI
import SwiftData

/// Vista dedicata per "Da consumare" (scadono entro domani)
struct ToConsumeView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @Environment(\.modelContext) private var modelContext
    
    private var toConsumeItems: [FoodItem] {
        let calendar = Calendar.current
        let now = Date()
        let endOfTomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 2, to: now) ?? now)
        
        return allItems.filter { item in
            guard !item.isConsumed else { return false }
            let expiry = item.effectiveExpirationDate
            // Escludi quelli che scadono oggi (sono in "Scadono oggi")
            let endOfToday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
            if expiry < endOfToday || calendar.isDate(expiry, inSameDayAs: now) {
                return false
            }
            // Include solo quelli che scadono entro domani
            return expiry < endOfTomorrow
        }
    }
    
    var body: some View {
        Group {
            if toConsumeItems.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Niente di urgente 👍")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Non ci sono prodotti da consumare entro domani")
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
                    ForEach(toConsumeItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            ToConsumeCard(item: item)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                item.isConsumed = true
                                item.consumedDate = Date()
                                item.lastUpdated = Date()
                                try? modelContext.save()
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
                        }
                    }
                }
            }
        }
        .navigationTitle("Da consumare")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ToConsumeCard: View {
    let item: FoodItem
    
    var body: some View {
        HStack(spacing: 12) {
            // Icona categoria
            Image(systemName: item.category.icon)
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
                    Label(item.effectiveExpirationDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    if item.daysRemaining == 1 {
                        Text("Domani")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.orange)
                    }
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
    ToConsumeView()
        .modelContainer(for: FoodItem.self)
}

