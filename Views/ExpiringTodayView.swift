import SwiftUI
import SwiftData

/// Vista dedicata per i prodotti che scadono oggi
struct ExpiringTodayView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var themeManager = ThemeManager.shared
    
    private var expiringTodayItems: [FoodItem] {
        let calendar = Calendar.current
        let now = Date()
        let endOfToday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        
        return allItems.filter { item in
            guard !item.isConsumed else { return false }
            let expiry = item.effectiveExpirationDate
            // Scadono oggi: expiryDate <= endOfToday
            return expiry < endOfToday || calendar.isDate(expiry, inSameDayAs: now)
        }
    }
    
    var body: some View {
        ScrollView {
            if expiringTodayItems.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(expiringTodayItems) { item in
                        ExpiringTodayItemCard(item: item)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Scadono Oggi")
        .navigationBarTitleDisplayMode(.inline)
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
            
            Text("Ottimo! Non ci sono prodotti che scadono oggi")
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

// MARK: - Expiring Today Item Card
private struct ExpiringTodayItemCard: View {
    let item: FoodItem
    @StateObject private var themeManager = ThemeManager.shared
    
    private var isExpired: Bool {
        item.expirationStatus == .expired
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icona categoria con badge urgenza
            ZStack {
                Image(systemName: item.category.icon)
                    .font(.system(size: 32))
                    .foregroundColor(categoryColor)
                    .frame(width: 60, height: 60)
                    .background(categoryColor.opacity(0.15))
                    .cornerRadius(12)
                
                if isExpired {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .offset(x: 22, y: -22)
                }
            }
            
            // Informazioni principali
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name)
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundColor(.primary)
                
                HStack(spacing: 16) {
                    Label("\(item.quantity)", systemImage: "number")
                    Text("•")
                        .foregroundColor(.secondary)
                    Label(item.category.rawValue, systemImage: item.category.icon)
                }
                .font(.system(size: 15, weight: .regular, design: .default))
                .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    Image(systemName: isExpired ? "exclamationmark.triangle.fill" : "clock.fill")
                        .font(.system(size: 12))
                    Text(isExpired ? "Scaduto" : "Scade oggi")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(item.expirationDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 14, weight: .regular, design: .default))
                }
                .foregroundColor(isExpired ? .red : .orange)
            }
            
            Spacer()
            
            // Badge urgenza
            VStack {
                Text(isExpired ? "Scaduto" : "Oggi")
                    .font(.system(size: 12, weight: .bold, design: .default))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(isExpired ? Color.red : Color.orange)
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isExpired ? Color.red.opacity(0.3) : Color.orange.opacity(0.3), lineWidth: 2)
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
        ExpiringTodayView()
            .modelContainer(for: FoodItem.self, inMemory: true)
    }
}

