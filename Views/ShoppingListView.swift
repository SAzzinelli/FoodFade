import SwiftUI
import SwiftData

/// Lista della spesa: cosa comprare (manuale, da consumati, export Promemoria)
struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingItem.addedAt, order: .reverse) private var allItems: [ShoppingItem]
    
    @State private var newItemName = ""
    @State private var showingAddFromConsumed = false
    
    private var pendingItems: [ShoppingItem] {
        allItems.filter { !$0.isCompleted }
    }
    
    private var completedItems: [ShoppingItem] {
        allItems.filter { $0.isCompleted }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Campo aggiungi voce
                HStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(ThemeManager.shared.primaryColor)
                    TextField("shopping.add.placeholder".localized, text: $newItemName)
                        .textFieldStyle(.plain)
                        .onSubmit { addCurrentItem() }
                    Button {
                        addCurrentItem()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(ThemeManager.shared.primaryColor)
                            .clipShape(Circle())
                    }
                    .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground))
                
                if allItems.isEmpty {
                    emptyState
                } else {
                    List {
                        if !pendingItems.isEmpty {
                            Section {
                                ForEach(pendingItems) { item in
                                    ShoppingListRow(item: item, onToggle: { toggleItem(item) }, onDelete: { deleteItem(item) })
                                }
                            }
                        }
                        
                        if !completedItems.isEmpty {
                            Section("shopping.completed".localized) {
                                ForEach(completedItems) { item in
                                    ShoppingListRow(item: item, onToggle: { toggleItem(item) }, onDelete: { deleteItem(item) })
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("shopping.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddFromConsumed = true
                        } label: {
                            Label("shopping.add_from_consumed".localized, systemImage: "clock.arrow.circlepath")
                        }
                        Button {
                            exportToReminders()
                        } label: {
                            Label("shopping.export_reminders".localized, systemImage: "calendar.badge.plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddFromConsumed) {
                AddFromConsumedSheet(onSelect: { name in
                    addItem(name: name)
                    showingAddFromConsumed = false
                }, onDismiss: { showingAddFromConsumed = false })
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    private var emptyState: some View {
        ContentUnavailableView(
            "shopping.empty.title".localized,
            systemImage: "cart",
            description: Text("shopping.empty.subtitle".localized)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func addCurrentItem() {
        let name = newItemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        addItem(name: name)
        newItemName = ""
    }
    
    private func addItem(name: String) {
        let item = ShoppingItem(name: name)
        modelContext.insert(item)
        try? modelContext.save()
    }
    
    private func toggleItem(_ item: ShoppingItem) {
        item.isCompleted.toggle()
        item.completedAt = item.isCompleted ? Date() : nil
        try? modelContext.save()
    }
    
    private func deleteItem(_ item: ShoppingItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    private func exportToReminders() {
        guard !pendingItems.isEmpty else { return }
        EventKitHelper.shared.requestAccess { granted in
            if granted {
                for item in pendingItems {
                    EventKitHelper.shared.addReminder(title: item.name)
                }
            }
        }
    }
}

private struct ShoppingListRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button {
                onToggle()
            } label: {
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(item.isCompleted ? .green : ThemeManager.shared.primaryColor)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16, weight: .medium))
                    .strikethrough(item.isCompleted, color: .secondary)
                    .foregroundColor(item.isCompleted ? .secondary : .primary)
                if item.quantity > 1 {
                    Text("× \(item.quantity)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("common.delete".localized, systemImage: "trash")
            }
            .tint(.red)
        }
    }
}

/// Sheet: scegli da prodotti recentemente consumati da aggiungere alla lista
private struct AddFromConsumedSheet: View {
    @Query(sort: \FoodItem.consumedDate, order: .reverse) private var consumed: [FoodItem]
    let onSelect: (String) -> Void
    let onDismiss: () -> Void
    
    private var recentConsumed: [FoodItem] {
        consumed.filter { $0.isConsumed && $0.consumedDate != nil }.prefix(30).map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(recentConsumed) { item in
                    Button {
                        onSelect(item.name)
                    } label: {
                        HStack {
                            Text(item.name)
                            Spacer()
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(ThemeManager.shared.primaryColor)
                        }
                    }
                }
            }
            .navigationTitle("shopping.add_from_consumed".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized, action: onDismiss)
                }
            }
        }
    }
}

// MARK: - EventKit helper per Promemoria
import EventKit

final class EventKitHelper {
    static let shared = EventKitHelper()
    private let store = EKEventStore()
    
    private init() {}
    
    func requestAccess(completion: @escaping (Bool) -> Void) {
        store.requestFullAccessToReminders { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }
    
    func addReminder(title: String) {
        guard let calendar = store.defaultCalendarForNewReminders() else { return }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = calendar
        try? store.save(reminder, commit: true)
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(for: ShoppingItem.self)
}
