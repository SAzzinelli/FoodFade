import SwiftUI
import SwiftData

/// Vista dedicata per i prodotti che scadono oggi
struct ExpiringTodayView: View {
    @Query(sort: \FoodItem.expirationDate, order: .forward) private var allItems: [FoodItem]
    @Environment(\.modelContext) private var modelContext
    @State private var fridgyMessage: String?
    @State private var fridgyContext: FridgyContext?
    @State private var isLoadingFridgy = false
    private let fridgyService = FridgyServiceImpl.shared
    
    private var expiringTodayItems: [FoodItem] {
        let calendar = Calendar.current
        let now = Date()
        let endOfToday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        
        return allItems.filter { item in
            guard !item.isConsumed else { return false }
            let expiry = item.effectiveExpirationDate
            return expiry < endOfToday || calendar.isDate(expiry, inSameDayAs: now)
        }
    }
    
    var body: some View {
        Group {
            if expiringTodayItems.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Nessun prodotto in scadenza")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text("Ottimo! Non ci sono prodotti che scadono oggi")
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
                    ForEach(expiringTodayItems) { item in
                        NavigationLink {
                            ItemDetailView(item: item)
                        } label: {
                            ExpiringTodayCard(item: item)
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
                            .tint(.red)
                        }
                    }
                    if IntelligenceManager.shared.isFridgyAvailable {
                        Section {
                            if isLoadingFridgy {
                                FridgySkeletonLoader()
                            } else if let message = fridgyMessage, let context = fridgyContext {
                                FridgyCard(context: context, message: message)
                            }
                        } header: {
                            Text("Suggerimenti di Fridgy")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Scadono oggi")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !expiringTodayItems.isEmpty { loadFridgy() }
        }
        .onChange(of: expiringTodayItems.count) { _, _ in
            if !expiringTodayItems.isEmpty { loadFridgy() }
        }
    }
    
    private func loadFridgy() {
        guard IntelligenceManager.shared.isFridgyAvailable,
              let payload = FridgyPayload.forExpiringTodaySection(items: expiringTodayItems) else { return }
        isLoadingFridgy = true
        Task {
            do {
                let text = try await fridgyService.generateMessage(from: payload.promptContext)
                let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                await MainActor.run {
                    fridgyMessage = sanitized.isEmpty ? nil : String(sanitized.prefix(100))
                    fridgyContext = payload.context
                    isLoadingFridgy = false
                }
            } catch {
                await MainActor.run {
                    fridgyMessage = nil
                    fridgyContext = nil
                    isLoadingFridgy = false
                }
            }
        }
    }
}

// MARK: - Expiring Today Card (stile uniforme a ToConsumeCard)
private struct ExpiringTodayCard: View {
    let item: FoodItem
    
    private var isExpired: Bool {
        item.expirationStatus == .expired
    }
    
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
                    
                    Text(isExpired ? "Scaduto" : "Oggi")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isExpired ? .red : .orange)
                    
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
    NavigationStack {
        ExpiringTodayView()
            .modelContainer(for: FoodItem.self, inMemory: true)
    }
}
