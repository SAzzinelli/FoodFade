import SwiftUI
import SwiftData

/// Storico / Diario dei prodotti consumati (per giorno e settimana)
struct ConsumedHistoryView: View {
    @Query(sort: \FoodItem.consumedDate, order: .reverse) private var allItems: [FoodItem]
    @Environment(\.modelContext) private var modelContext
    @State private var showingDeleteAllAlert = false
    
    private var consumedItems: [FoodItem] {
        allItems.filter { $0.isConsumed && $0.consumedDate != nil }
    }
    
    private var groupedByDate: [(String, [FoodItem])] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        
        let otherKey = "history.older".localized
        let grouped = Dictionary(grouping: consumedItems) { item -> String in
            guard let date = item.consumedDate else { return otherKey }
            let start = calendar.startOfDay(for: date)
            if start == startOfToday {
                return "history.today".localized
            }
            if let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday), start == yesterday {
                return "history.yesterday".localized
            }
            if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
                return "history.this_week".localized
            }
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.locale = Locale.current
            return formatter.string(from: date)
        }
        
        let order = ["history.today".localized, "history.yesterday".localized, "history.this_week".localized, otherKey]
        return grouped.sorted { pair1, pair2 in
            let i1 = order.firstIndex(of: pair1.key) ?? 999
            let i2 = order.firstIndex(of: pair2.key) ?? 999
            if i1 != i2 { return i1 < i2 }
            return (pair1.value.first?.consumedDate ?? .distantPast) > (pair2.value.first?.consumedDate ?? .distantPast)
        }
    }
    
    var body: some View {
        Group {
            if consumedItems.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(groupedByDate, id: \.0) { sectionTitle, items in
                        Section {
                            ForEach(items) { item in
                                ConsumedHistoryRow(item: item)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            modelContext.delete(item)
                                            try? modelContext.save()
                                        } label: {
                                            Label("common.delete".localized, systemImage: "trash.fill")
                                        }
                                        .tint(.red)
                                    }
                            }
                        } header: {
                            Text(sectionTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .toolbar {
                    if !consumedItems.isEmpty {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(role: .destructive) {
                                showingDeleteAllAlert = true
                            } label: {
                                Label("history.delete_all".localized, systemImage: "trash")
                            }
                            .foregroundColor(.primary)
                        }
                    }
                }
                .alert("history.delete_all".localized, isPresented: $showingDeleteAllAlert) {
                    Button("common.cancel".localized, role: .cancel) { }
                    Button("common.delete".localized, role: .destructive) {
                        deleteAllConsumed()
                    }
                } message: {
                    Text("history.delete_all.message".localized)
                }
            }
        }
        .navigationTitle("history.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "history.empty.title".localized,
            systemImage: "checkmark.circle",
            description: Text("history.empty.subtitle".localized)
        )
    }
    
    private func deleteAllConsumed() {
        for item in consumedItems {
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

private struct ConsumedHistoryRow: View {
    let item: FoodItem
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: item.category.icon)
                .font(.system(size: 18))
                .foregroundColor(AppTheme.color(for: item.category))
                .frame(width: 32, alignment: .center)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16, weight: .medium))
                if let date = item.consumedDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("\(item.quantity)")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        ConsumedHistoryView()
            .modelContainer(for: FoodItem.self)
    }
}
