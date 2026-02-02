import SwiftUI
import SwiftData

/// Picker per selezionare il tipo di alimento – sheet dal basso con lista e ricerca
struct FoodTypePicker: View {
    @Binding var selectedFoodType: FoodType?
    @Environment(\.modelContext) private var modelContext
    @Query private var customTypes: [CustomFoodType]
    @State private var showingSheet = false
    @State private var showingAddCustomType = false
    @State private var customTypeName = ""
    
    private var allFoodTypes: [FoodType] {
        var types = FoodType.defaultTypes
        let custom = customTypes.map { $0.toFoodType() }
        types.append(contentsOf: custom)
        return types
    }
    
    var body: some View {
        Button {
            showingSheet = true
        } label: {
            HStack {
                if let foodType = selectedFoodType {
                    Text(foodType.rawValue)
                        .foregroundColor(.primary)
                } else {
                    Text("addfood.foodtype.optional".localized)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSheet) {
            FoodTypeSheetView(
                allTypes: allFoodTypes,
                selectedFoodType: $selectedFoodType,
                onDismiss: { showingSheet = false },
                onAddCustom: { showingAddCustomType = true }
            )
        }
        .alert("addfood.foodtype.add.title".localized, isPresented: $showingAddCustomType) {
            TextField("addfood.foodtype.add.name".localized, text: $customTypeName)
            Button("common.cancel".localized, role: .cancel) {
                customTypeName = ""
            }
            Button("common.add".localized) {
                addCustomType()
            }
            .disabled(customTypeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("addfood.foodtype.add.message".localized)
        }
    }
    
    private func addCustomType() {
        let name = customTypeName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        let existing = allFoodTypes.first { $0.rawValue == name }
        if existing != nil {
            customTypeName = ""
            return
        }
        
        let customType = CustomFoodType(name: name)
        modelContext.insert(customType)
        
        do {
            try modelContext.save()
            selectedFoodType = customType.toFoodType()
            customTypeName = ""
        } catch {
            print("Errore nel salvataggio della categoria custom: \(error)")
        }
    }
}

// MARK: - Sheet con lista categorie (searchable)
private struct FoodTypeSheetView: View {
    let allTypes: [FoodType]
    @Binding var selectedFoodType: FoodType?
    var onDismiss: () -> Void
    var onAddCustom: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredTypes: [FoodType] {
        if searchText.isEmpty { return allTypes }
        return allTypes.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedFoodType = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("addfood.foodtype.none".localized)
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedFoodType == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(ThemeManager.shared.primaryColor)
                            }
                        }
                    }
                }
                
                Section {
                    ForEach(filteredTypes, id: \.id) { foodType in
                        Button {
                            selectedFoodType = foodType
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: foodType.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(ThemeManager.shared.primaryColor)
                                    .frame(width: 28, alignment: .center)
                                Text(foodType.rawValue)
                                    .foregroundColor(.primary)
                                Spacer()
                                if selectedFoodType?.id == foodType.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(ThemeManager.shared.primaryColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Categorie")
                }
                
                Section {
                    Button {
                        dismiss()
                        onAddCustom()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(ThemeManager.shared.primaryColor)
                            Text("addfood.foodtype.add".localized)
                                .foregroundColor(ThemeManager.shared.primaryColor)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Cerca categoria")
            .navigationTitle("Categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    Form {
        FoodTypePicker(selectedFoodType: .constant(.vegetables))
    }
}
