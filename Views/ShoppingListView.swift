import SwiftUI
import SwiftData

/// Lista della spesa: gestione più liste, aggiungi voce, da consumati, swipe → comprato (Archiviati)
struct ShoppingListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ShoppingList.createdAt, order: .reverse) private var allLists: [ShoppingList]
    
    @State private var showingNewList = false
    @State private var newListName = ""
    
    var body: some View {
        NavigationStack {
            Group {
                if allLists.isEmpty {
                    emptyListsState
                } else {
                    List {
                        ForEach(allLists) { list in
                            NavigationLink {
                                ShoppingListDetailView(list: list)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: list.iconName)
                                        .font(.system(size: 20))
                                        .foregroundColor(ThemeManager.shared.primaryColor)
                                        .frame(width: 32)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(list.name)
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundColor(.primary)
                                        Text(String(format: "shopping.list.count".localized, list.pendingItems.count))
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteList(list)
                                } label: {
                                    Label("common.delete".localized, systemImage: "trash.fill")
                                }
                                .tint(.red)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("shopping.title".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newListName = ""
                        showingNewList = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingNewList) {
                newListSheet
            }
            .onAppear {
                if allLists.isEmpty {
                    createDefaultListIfNeeded()
                }
            }
        }
    }
    
    private var emptyListsState: some View {
        VStack(spacing: 24) {
            ContentUnavailableView(
                "shopping.lists.empty.title".localized,
                systemImage: "list.bullet.rectangle",
                description: Text("shopping.lists.empty.subtitle".localized)
            )
            Button("shopping.lists.new".localized) {
                newListName = ""
                showingNewList = true
            }
            .buttonStyle(.borderedProminent)
            .tint(ThemeManager.shared.primaryColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var newListSheet: some View {
        NavigationStack {
            Form {
                TextField("shopping.list.name.placeholder".localized, text: $newListName)
                    .textInputAutocapitalization(.sentences)
            }
            .navigationTitle("shopping.lists.new".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { showingNewList = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.add".localized) {
                        createList(name: newListName.trimmingCharacters(in: .whitespacesAndNewlines))
                        showingNewList = false
                    }
                    .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func createDefaultListIfNeeded() {
        guard allLists.isEmpty else { return }
        let defaultName = "shopping.list.default_name".localized
        createList(name: defaultName)
    }
    
    private func createList(name: String) {
        guard !name.isEmpty else { return }
        let list = ShoppingList(name: name)
        modelContext.insert(list)
        try? modelContext.save()
    }
    
    private func deleteList(_ list: ShoppingList) {
        modelContext.delete(list)
        try? modelContext.save()
    }
}

// MARK: - Dettaglio singola lista (voci, aggiungi, da consumati, archiviati)
struct ShoppingListDetailView: View {
    @Environment(\.modelContext) private var modelContext
    var list: ShoppingList
    
    @State private var newItemName = ""
    @State private var showingAddFromConsumed = false
    @State private var showingRename = false
    @State private var renameText = ""
    @State private var showingIconPicker = false
    @State private var itemToEdit: ShoppingItem?
    @State private var isAcquistatiExpanded = false
    
    private var pendingItems: [ShoppingItem] {
        list.pendingItems.sorted { $0.addedAt > $1.addedAt }
    }
    
    private var archivedItems: [ShoppingItem] {
        list.archivedItems.sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Aggiungi voce (un solo + a destra)
            HStack(spacing: 12) {
                TextField("shopping.add.placeholder".localized, text: $newItemName)
                    .textFieldStyle(.plain)
                    .onSubmit { addCurrentItem() }
                Button {
                    addCurrentItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(ThemeManager.shared.primaryColor)
                }
                .buttonStyle(.plain)
                .disabled(newItemName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
            
            if list.items.isEmpty {
                emptyListState
            } else {
                List {
                    if !pendingItems.isEmpty {
                        Section {
                            ForEach(pendingItems) { item in
                                ShoppingListRow(item: item, onToggle: { markAsBought(item) }, onDelete: { deleteItem(item) }, onEdit: { itemToEdit = item })
                            }
                            .onDelete(perform: deletePendingItems)
                        }
                    }
                    
                    if !archivedItems.isEmpty {
                        Section {
                            DisclosureGroup(isExpanded: $isAcquistatiExpanded) {
                                ForEach(archivedItems) { item in
                                    ShoppingListRow(item: item, onToggle: { unmarkBought(item) }, onDelete: { deleteItem(item) }, onEdit: { itemToEdit = item })
                                }
                                .onDelete(perform: deleteArchivedItems)
                            } label: {
                                Text("shopping.purchased_section".localized)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(list.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        renameText = list.name
                        showingRename = true
                    } label: {
                        Label("common.edit".localized, systemImage: "pencil")
                    }
                    Button {
                        showingIconPicker = true
                    } label: {
                        Label("shopping.list.change_icon".localized, systemImage: "square.grid.2x2")
                    }
                    Button {
                        showingAddFromConsumed = true
                    } label: {
                        Label("shopping.add_from_consumed".localized, systemImage: "clock.arrow.circlepath")
                    }
                    Button {
                        exportListToReminders()
                    } label: {
                        Label("shopping.export_reminders".localized, systemImage: "calendar.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingAddFromConsumed) {
            AddFromConsumedSheet(onSelect: { name in
                addItem(name: name)
                showingAddFromConsumed = false
            }, onDismiss: { showingAddFromConsumed = false })
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showingIconPicker) {
            ShoppingListIconPicker(currentIconName: list.iconName) { newName in
                list.iconName = newName
                try? modelContext.save()
                showingIconPicker = false
            }
        }
        .alert("shopping.list.rename".localized, isPresented: $showingRename) {
            TextField("shopping.list.name.placeholder".localized, text: $renameText)
                .textInputAutocapitalization(.sentences)
            Button("common.cancel".localized, role: .cancel) { }
            Button("common.save".localized) {
                list.name = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                if list.name.isEmpty { list.name = "shopping.list.default_name".localized }
                try? modelContext.save()
            }
        } message: {
            Text("shopping.list.rename.hint".localized)
        }
        .sheet(item: $itemToEdit) { item in
            EditShoppingItemSheet(item: item, onDismiss: { itemToEdit = nil })
        }
    }
    
    private var emptyListState: some View {
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
        let item = ShoppingItem(name: name, list: list)
        modelContext.insert(item)
        try? modelContext.save()
    }
    
    /// Swipe / segna come comprato → va in Archiviati
    private func markAsBought(_ item: ShoppingItem) {
        item.isCompleted = true
        item.completedAt = Date()
        try? modelContext.save()
    }
    
    private func unmarkBought(_ item: ShoppingItem) {
        item.isCompleted = false
        item.completedAt = nil
        try? modelContext.save()
    }
    
    private func deleteItem(_ item: ShoppingItem) {
        modelContext.delete(item)
        try? modelContext.save()
    }
    
    private func deletePendingItems(at offsets: IndexSet) {
        for index in offsets {
            let item = pendingItems[index]
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
    
    private func deleteArchivedItems(at offsets: IndexSet) {
        for index in offsets {
            let item = archivedItems[index]
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
    
    private func exportListToReminders() {
        let toExport = pendingItems
        guard !toExport.isEmpty else { return }
        EventKitHelper.shared.requestAccess { granted in
            if granted {
                for item in toExport {
                    EventKitHelper.shared.addReminder(title: item.name)
                }
            }
        }
    }
}

// MARK: - Riga voce (checkbox, nome tappabile per modifica, quantità; swipe Acquistato / Elimina)
private struct ShoppingListRow: View {
    let item: ShoppingItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    
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
            
            Button {
                onEdit()
            } label: {
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
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button {
                onToggle()
            } label: {
                Label("shopping.purchased".localized, systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
            Button(role: .destructive, action: onDelete) {
                Label("common.delete".localized, systemImage: "trash")
            }
            .tint(.red)
        }
    }
}

// MARK: - Picker icona lista (icone di sistema)
private struct ShoppingListIconPicker: View {
    let currentIconName: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))], spacing: 16) {
                ForEach(ShoppingList.availableIcons, id: \.self) { iconName in
                    Button {
                        onSelect(iconName)
                        dismiss()
                    } label: {
                        Image(systemName: iconName)
                            .font(.system(size: 28))
                            .foregroundColor(iconName == currentIconName ? ThemeManager.shared.primaryColor : .primary)
                            .frame(width: 56, height: 56)
                            .background(iconName == currentIconName ? ThemeManager.shared.primaryColor.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .navigationTitle("shopping.list.change_icon".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sheet modifica testo voce
private struct EditShoppingItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let item: ShoppingItem
    let onDismiss: () -> Void
    
    @State private var editedName: String = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("shopping.add.placeholder".localized, text: $editedName)
                    .textInputAutocapitalization(.sentences)
            }
            .navigationTitle("common.edit".localized)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { editedName = item.name }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) { onDismiss(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save".localized) {
                        item.name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                        if item.name.isEmpty { item.name = " " }
                        try? modelContext.save()
                        onDismiss(); dismiss()
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Sheet: da consumati
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

// MARK: - EventKit (Promemoria)
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
        .modelContainer(for: [ShoppingList.self, ShoppingItem.self])
}
