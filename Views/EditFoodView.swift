import SwiftUI
import SwiftData

/// Vista per modificare un alimento esistente
struct EditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let item: FoodItem
    
    @State private var name: String
    @State private var category: FoodCategory
    @State private var foodType: FoodType?
    @State private var expirationDate: Date
    @State private var quantity: Int
    @State private var notes: String
    @State private var notify: Bool
    @State private var selectedPhoto: UIImage?
    
    @State private var isGlutenFree: Bool
    @State private var isBio: Bool
    @State private var isFresh: Bool
    @State private var isOpened: Bool
    
    init(item: FoodItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _foodType = State(initialValue: item.foodType)
        _isGlutenFree = State(initialValue: item.isGlutenFree)
        _isBio = State(initialValue: item.isBio)
        _expirationDate = State(initialValue: item.expirationDate)
        _quantity = State(initialValue: item.quantity)
        _notes = State(initialValue: item.notes ?? "")
        _notify = State(initialValue: item.notify)
        _isFresh = State(initialValue: item.isFresh)
        _isOpened = State(initialValue: item.isOpened)
        _selectedPhoto = State(initialValue: item.photoData.flatMap { UIImage(data: $0) })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nome prodotto", text: $name)
                } header: {
                    Text("Prodotto")
                }
                
                // Foto prodotto
                Section {
                    PhotoPickerView(selectedImage: $selectedPhoto)
                } header: {
                    Text("Foto")
                } footer: {
                    if selectedPhoto != nil {
                        Text("Puoi eliminare o cambiare la foto")
                    } else {
                        Text("Aggiungi una foto per identificare meglio il prodotto")
                    }
                }
                
                Section {
                    CategoryPicker(selectedCategory: $category)
                } header: {
                    Text("Categoria di conservazione")
                }
                
                Section {
                    FoodTypePicker(selectedFoodType: $foodType)
                } header: {
                    Text("Tipo di alimento")
                } footer: {
                    Text("Scegli il tipo di alimento per statistiche migliori")
                }
                
                Section {
                    Toggle(isOn: $isGlutenFree) {
                        Label("tags.gluten_free".localized, systemImage: "leaf.fill")
                    }
                    Toggle(isOn: $isBio) {
                        Label("tags.bio".localized, systemImage: "leaf.circle.fill")
                    }
                } header: {
                    Text("tags.section".localized)
                }
                
                Section {
                    // Se è fresco, mostra solo info
                    if isFresh {
                        HStack {
                            Label("Prodotto fresco", systemImage: "leaf.fill")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("Scade dopo 3 giorni")
                                .foregroundColor(.secondary)
                                .font(.subheadline)
                        }
                        
                        // Permetti di cambiare in prodotto con data
                        Button {
                            isFresh = false
                        } label: {
                            Text("Cambia in prodotto con data")
                                .foregroundColor(.accentColor)
                        }
                    } else {
                        // Prodotto con data di scadenza
                        DatePicker(
                            "Data di scadenza",
                            selection: $expirationDate,
                            displayedComponents: .date
                        )
                        
                        // Toggle prodotto aperto (solo se non fresco)
                        Toggle("Ho aperto questo prodotto", isOn: Binding(
                            get: { isOpened },
                            set: { newValue in
                                isOpened = newValue
                                if newValue {
                                    // Se viene aperto ora, imposta la data di apertura
                                    item.openedDate = Date()
                                } else {
                                    // Se viene chiuso, resetta la data di apertura
                                    item.openedDate = nil
                                }
                            }
                        ))
                        
                        if isOpened {
                            if let openedDate = item.openedDate {
                                HStack {
                                    Text("Aperto il")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(openedDate.formatted(date: .abbreviated, time: .omitted))
                                        .foregroundColor(.secondary)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    
                    Stepper("Quantità: \(quantity)", value: $quantity, in: 1...99)
                } header: {
                    Text("Scadenza")
                } footer: {
                    if isFresh {
                        Text("I prodotti freschi scadono automaticamente dopo 3 giorni.")
                    } else if isOpened {
                        Text("Un prodotto aperto scade dopo 3 giorni dalla data di apertura, invece della data originale.")
                    } else {
                        Text("Puoi segnarlo come aperto quando lo usi per la prima volta.")
                    }
                }
                
                Section {
                    Toggle("Notifiche", isOn: $notify)
                    
                    TextField("Note (opzionale)", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Preferenze")
                }
            }
            .navigationTitle("Modifica Prodotto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        item.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        item.category = category
        item.foodType = foodType
        
        // Calcola la data di scadenza base secondo la nuova logica
        let calendar = Calendar.current
        if isFresh {
            // Prodotto fresco: 3 giorni dalla creazione
            item.expirationDate = calendar.date(byAdding: .day, value: 3, to: item.createdAt) ?? expirationDate
        } else if isOpened, let openedDate = item.openedDate {
            // Prodotto aperto: 3 giorni dall'apertura
            item.expirationDate = calendar.date(byAdding: .day, value: 3, to: openedDate) ?? expirationDate
        } else {
            // Standard: usa la data inserita
            item.expirationDate = expirationDate
        }
        
        item.quantity = quantity
        item.notes = notes.isEmpty ? nil : notes
        item.notify = notify
        item.isGlutenFree = isGlutenFree
        item.isBio = isBio
        item.isFresh = isFresh
        item.isOpened = isOpened
        item.lastUpdated = Date()
        
        // Salva foto se presente
        if let photo = selectedPhoto {
            item.photoData = photo.jpegData(compressionQuality: 0.8)
        } else {
            item.photoData = nil
        }
        
        do {
            try modelContext.save()
            
            // Aggiorna notifiche
            Task {
                let settingsDescriptor = FetchDescriptor<AppSettings>()
                if let settings = try? modelContext.fetch(settingsDescriptor).first {
                    await NotificationService.shared.scheduleNotifications(
                        for: item,
                        daysBefore: settings.effectiveNotificationDays
                    )
                }
            }
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            dismiss()
        } catch {
            print("Errore nel salvataggio: \(error)")
        }
    }
}

#Preview {
    EditFoodView(item: FoodItem(
        name: "Yogurt",
        category: .fridge,
        expirationDate: Date()
    ))
    .modelContainer(for: FoodItem.self)
}

