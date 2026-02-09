import SwiftUI
import SwiftData

/// Vista per modificare un alimento esistente
struct EditFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    @Query private var settings: [AppSettings]
    @ObservedObject private var dictationService = ExpirationDictationService.shared
    
    let item: FoodItem
    
    @State private var name: String
    @State private var showingDictationOverlay = false
    @State private var showingDatePicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var errorTitle = ""
    @State private var category: FoodCategory
    @State private var foodType: FoodType?
    @State private var expirationDate: Date
    @State private var quantity: Int
    @State private var notes: String
    @State private var notify: Bool
    @State private var selectedPhoto: UIImage?
    
    @State private var isGlutenFree: Bool
    @State private var isBio: Bool
    @State private var isVegan: Bool
    @State private var isLactoseFree: Bool
    @State private var isVegetarian: Bool
    @State private var isReady: Bool
    @State private var needsCooking: Bool
    @State private var isArtisan: Bool
    @State private var isSinglePortion: Bool
    @State private var isMultiPortion: Bool
    @State private var isFresh: Bool
    @State private var isOpened: Bool
    
    init(item: FoodItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _category = State(initialValue: item.category)
        _foodType = State(initialValue: item.foodType)
        _isGlutenFree = State(initialValue: item.isGlutenFree)
        _isBio = State(initialValue: item.isBio)
        _isVegan = State(initialValue: item.isVegan)
        _isLactoseFree = State(initialValue: item.isLactoseFree)
        _isVegetarian = State(initialValue: item.isVegetarian)
        _isReady = State(initialValue: item.isReady)
        _needsCooking = State(initialValue: item.needsCooking)
        _isArtisan = State(initialValue: item.isArtisan)
        _isSinglePortion = State(initialValue: item.isSinglePortion)
        _isMultiPortion = State(initialValue: item.isMultiPortion)
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            EditLabelPill(title: "tags.gluten_free".localized, icon: "heart.text.square.fill", color: ThemeManager.shared.semanticIconColor(for: .tagGlutenFree), isOn: $isGlutenFree)
                            EditLabelPill(title: "tags.bio".localized, icon: "leaf.fill", color: ThemeManager.shared.semanticIconColor(for: .tagBio), isOn: $isBio)
                            EditLabelPill(title: "tags.vegan".localized, icon: "carrot.fill", color: .green, isOn: $isVegan)
                            EditLabelPill(title: "tags.lactose_free".localized, icon: "drop.fill", color: .blue, isOn: $isLactoseFree)
                            EditLabelPill(title: "tags.vegetarian".localized, icon: "leaf.circle.fill", color: .green, isOn: $isVegetarian)
                            EditLabelPill(title: "tags.ready".localized, icon: "checkmark.circle.fill", color: .green, isOn: $isReady)
                            EditLabelPill(title: "tags.to_cook".localized, icon: "flame.fill", color: .orange, isOn: $needsCooking)
                            EditLabelPill(title: "tags.artisan".localized, icon: "hammer.fill", color: .brown, isOn: $isArtisan)
                            EditLabelPill(title: "tags.single_portion".localized, icon: "person.fill", color: .purple, isOn: $isSinglePortion)
                            EditLabelPill(title: "tags.multi_portion".localized, icon: "person.3.fill", color: .purple, isOn: $isMultiPortion)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("addfood.labels".localized)
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
                        // Prodotto con data: dettatura + tap sulla data apre il date picker
                        HStack(spacing: 12) {
                            Button {
                                showingDictationOverlay = true
                                Task {
                                    await dictationService.startListening(
                                        onDate: { date in
                                            expirationDate = date
                                            showingDictationOverlay = false
                                        },
                                        onError: { key in
                                            if key == "addfood.dictation.error.no_date" {
                                                errorTitle = "addfood.dictation.error.title.no_date".localized
                                                errorMessage = "addfood.dictation.error.message.no_date".localized
                                            } else {
                                                errorTitle = "addfood.dictation.error.title.not_heard".localized
                                                errorMessage = "addfood.dictation.error.message.not_heard".localized
                                            }
                                            showingError = true
                                            showingDictationOverlay = false
                                        }
                                    )
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 16))
                                    Text("addfood.dictation.button".localized)
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundColor(colorScheme == .dark ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(colorScheme == .dark ? Color(white: 0.92) : ThemeManager.shared.primaryColor)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .disabled(dictationService.isListening)
                            
                            Button {
                                showingDatePicker = true
                            } label: {
                                Text(expirationDate.expirationShortLabel)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                        
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
            .tint(colorScheme == .dark ? ThemeManager.naturalHomeLogoColor : ThemeManager.shared.primaryColor)
            .fullScreenCover(isPresented: $showingDictationOverlay) {
                DictationListeningOverlay(
                    isPresented: $showingDictationOverlay,
                    onDismiss: { dictationService.stopListening() }
                )
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePicker(
                        "Data di scadenza",
                        selection: $expirationDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding()
                    .navigationTitle("Data di scadenza")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fatto") {
                                showingDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.height(420)])
                .presentationCompactAdaptation(.popover)
            }
            .alert(errorTitle, isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
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
        item.isVegan = isVegan
        item.isLactoseFree = isLactoseFree
        item.isVegetarian = isVegetarian
        item.isReady = isReady
        item.needsCooking = needsCooking
        item.isArtisan = isArtisan
        item.isSinglePortion = isSinglePortion
        item.isMultiPortion = isMultiPortion
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

private struct EditLabelPill: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 6) {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isOn ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isOn ? color : color.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
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

