import SwiftUI
import SwiftData

/// Vista per aggiungere un nuovo alimento
struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    /// Grigio scuro come l’icona (i) in Impostazioni → Versione (toggle, icone, pulsanti)
    private var addFormControlColor: Color {
        Color(red: 0.4, green: 0.5, blue: 0.6)
    }
    
    @Query private var settings: [AppSettings]
    @StateObject private var viewModel = AddFoodViewModel()
    @StateObject private var scannerService = BarcodeScannerService()
    @ObservedObject private var dictationService = ExpirationDictationService.shared
    
    @State private var showingScanner = false
    @State private var showingDictationOverlay = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var errorTitle = ""
    @State private var savedSuccessfully = false
    @State private var showingSuggestions = false
    @State private var showingFullScreenImage = false
    @State private var isPhotoSectionExpanded = false
    @State private var showNotesField = false
    @State private var showingPhotoSourceDialog = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingDocumentPicker = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    storageSection
                    nameAndPhotoSection
                    barcodeSection
                    expirationSection
                    quantitySection
                    labelsSection
                    notificationsAndNotesSection
                }
                .listStyle(.insetGrouped)
                .tint(addFormControlColor)
                
                suggestionsOverlay
            }
            .navigationTitle("addfood.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        Task {
                            await saveItem()
                        }
                    }
                    .disabled(!viewModel.canSave)
                }
            }
            .tint(addFormControlColor)
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView(scannerService: scannerService) { barcode in
                    print("📥 AddFoodView - Callback barcode ricevuto: \(barcode)")
                    // Il barcode viene gestito nel callback
                    viewModel.handleBarcodeScanned(barcode)
                    print("✅ AddFoodView - handleBarcodeScanned chiamato")
                }
                .onDisappear {
                    print("👋 AddFoodView - BarcodeScannerView onDisappear")
                    // Assicurati che lo scanner si fermi quando la vista viene chiusa
                    scannerService.stopScanning()
                }
            }
            .sheet(isPresented: $showingFullScreenImage) {
                if let image = viewModel.selectedPhoto {
                    FullScreenImageView(image: image)
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(sourceType: .camera, selectedImage: $viewModel.selectedPhoto)
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                ImagePicker(sourceType: .photoLibrary, selectedImage: $viewModel.selectedPhoto)
            }
            .sheet(isPresented: $showingDocumentPicker) {
                DocumentPicker(selectedImage: $viewModel.selectedPhoto)
            }
            .onAppear {
                showNotesField = !viewModel.notes.isEmpty
            }
            .onChange(of: showingScanner) { oldValue, newValue in
                print("🔄 AddFoodView - showingScanner cambiato: \(oldValue) -> \(newValue)")
            }
            .fullScreenCover(isPresented: $showingDictationOverlay) {
                DictationListeningOverlay(
                    isPresented: $showingDictationOverlay,
                    onDismiss: { dictationService.stopListening() }
                )
            }
            .alert(errorTitle, isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                viewModel.setup(modelContext: modelContext)
            }
            .onTapGesture {
                // Chiudi i suggerimenti quando si tocca fuori
                showingSuggestions = false
            }
            .gesture(
                DragGesture()
                    .onEnded { _ in
                        showingSuggestions = false
                    }
            )
            .onChange(of: viewModel.isFresh) { oldValue, newValue in
                // La validazione viene gestita automaticamente nel ViewModel
                viewModel.validateDate()
            }
            // Il barcode viene gestito direttamente nel callback di BarcodeScannerView
            // Non serve un onChange aggiuntivo qui
        }
    }
    
    // MARK: - Sezioni (ordine come nell’esempio)
    
    private var storageSection: some View {
        Section {
            HStack(spacing: 12) {
                ForEach(FoodCategory.allCases, id: \.self) { category in
                    AddFoodStorageButton(
                        category: category,
                        isSelected: viewModel.category == category
                    ) {
                        viewModel.category = category
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Text("addfood.where_store".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var nameAndPhotoSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                TextField("addfood.name.placeholder".localized, text: $viewModel.name)
                    .onChange(of: viewModel.name) { _, newValue in
                        showingSuggestions = !newValue.isEmpty && !viewModel.filterSuggestions(for: newValue).isEmpty
                    }
                addPhotoButton
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Text("addfood.name".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var addPhotoButton: some View {
        Button {
            showingPhotoSourceDialog = true
        } label: {
            if let image = viewModel.selectedPhoto {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Circle())
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog("addfood.photo.optional".localized, isPresented: $showingPhotoSourceDialog) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("addfood.photo.take".localized) { showingCamera = true }
            }
            Button("addfood.photo.library".localized) { showingPhotoLibrary = true }
            Button("addfood.photo.file".localized) { showingDocumentPicker = true }
            Button("Annulla", role: .cancel) {}
        }
    }
    
    private var barcodeSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "barcode")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                if let barcode = viewModel.barcode {
                    Text(barcode)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    Text("addfood.barcode.placeholder".localized)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    showingScanner = true
                } label: {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 22))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Text("addfood.barcode".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var expirationSection: some View {
        let useDictation = (settings.first?.expirationInputMethod ?? .calendar) == .dictation
        return Section {
            Toggle("addfood.is_fresh".localized, isOn: $viewModel.isFresh)
            
            if !viewModel.isFresh {
                // Riga data in evidenza
                HStack {
                    Text(viewModel.expirationDate.expirationShortLabel)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(addFormControlColor)
                    Spacer()
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
                
                // Azione: dettatura o calendario
                if useDictation {
                    Button {
                        showingDictationOverlay = true
                        Task {
                            await dictationService.startListening(
                                onDate: { date in
                                    viewModel.expirationDate = date
                                    viewModel.validateDate()
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
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 18))
                            Text("addfood.dictation.button".localized)
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(addFormControlColor)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(dictationService.isListening)
                } else {
                    DatePicker(
                        "addfood.expiration".localized,
                        selection: $viewModel.expirationDate,
                        displayedComponents: .date
                    )
                    .onChange(of: viewModel.expirationDate) { _, _ in
                        viewModel.validateDate()
                    }
                }
                
                if let errorMessage = viewModel.dateValidationError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                }
            }
        } header: {
            Text("addfood.expiration_section".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var quantitySection: some View {
        Section {
            VStack(spacing: 16) {
                HStack(spacing: 24) {
                    Button {
                        if viewModel.quantity > 1 { viewModel.quantity -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.quantity > 1 ? addFormControlColor : Color(.tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.quantity <= 1)
                    
                    Text("\(viewModel.quantity)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .frame(minWidth: 44)
                    
                    Button {
                        if viewModel.quantity < 99 { viewModel.quantity += 1 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(viewModel.quantity < 99 ? addFormControlColor : Color(.tertiaryLabel))
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.quantity >= 99)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Text("addfood.quantity_section".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    private var labelsSection: some View {
        let allLabels: [(title: String, icon: String, color: Color, isSelected: Bool, action: () -> Void)] = [
            ("tags.vegan".localized, "carrot.fill", .green, viewModel.isVegan, { viewModel.isVegan.toggle() }),
            ("tags.vegetarian".localized, "leaf.circle.fill", .green, viewModel.isVegetarian, { viewModel.isVegetarian.toggle() }),
            ("tags.gluten_free".localized, "heart.text.square.fill", ThemeManager.shared.semanticIconColor(for: .tagGlutenFree), viewModel.isGlutenFree, { viewModel.isGlutenFree.toggle() }),
            ("tags.lactose_free".localized, "drop.fill", .blue, viewModel.isLactoseFree, { viewModel.isLactoseFree.toggle() }),
            ("tags.bio".localized, "leaf.fill", .green, viewModel.isBio, { viewModel.isBio.toggle() }),
            ("tags.ready".localized, "checkmark.circle.fill", .green, viewModel.isReady, { viewModel.isReady.toggle() }),
            ("tags.to_cook".localized, "flame.fill", .orange, viewModel.needsCooking, { viewModel.needsCooking.toggle() }),
            ("tags.artisan".localized, "hammer.fill", .brown, viewModel.isArtisan, { viewModel.isArtisan.toggle() }),
            ("tags.single_portion".localized, "person.fill", .purple, viewModel.isSinglePortion, { viewModel.isSinglePortion.toggle() }),
            ("tags.multi_portion".localized, "person.3.fill", .purple, viewModel.isMultiPortion, { viewModel.isMultiPortion.toggle() })
        ]
        return Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(allLabels.enumerated()), id: \.offset) { _, label in
                        AddFoodCharacteristicPill(
                            title: label.title,
                            icon: label.icon,
                            isSelected: label.isSelected,
                            color: label.color
                        ) { label.action() }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
        } header: {
            Text("addfood.labels".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
    
    /// Sottotitolo giorni notifica: rispetta Impostazioni (es. "1 giorno prima" se impostato 1)
    private var notifyDaysSubtitle: String {
        let days = settings.first?.effectiveNotificationDays ?? 1
        if days == 1 {
            return "addfood.notify_days.one".localized
        }
        return String(format: "addfood.notify_days.many".localized, days)
    }
    
    private var notificationsAndNotesSection: some View {
        Section {
            Toggle(isOn: $viewModel.notify) {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("addfood.notify_before".localized)
                            .foregroundColor(.primary)
                        Text(notifyDaysSubtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                    }
                }
            }
            
            Toggle(isOn: $showNotesField) {
                HStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("addfood.add_notes".localized)
                            .foregroundColor(.primary)
                        Text("addfood.add_notes.optional".localized)
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                    }
                }
            }
            
            if showNotesField {
                TextField("addfood.notes".localized, text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        }
    }
    
    @ViewBuilder
    private var suggestionsOverlay: some View {
        if showingSuggestions && !viewModel.name.isEmpty {
            let suggestions = viewModel.filterSuggestions(for: viewModel.name)
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button {
                            viewModel.name = suggestion.capitalized
                            showingSuggestions = false
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                Text(suggestion.capitalized)
                                    .foregroundColor(.primary)
                                    .font(.system(size: 16))
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        
                        if suggestion != suggestions.last {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
                .padding(.horizontal, 20)
                .padding(.top, 100)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    private func saveItem() async {
        do {
            try await viewModel.save()
            
            // Haptic feedback
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Helper views stile riferimento

private struct AddFoodStorageButton: View {
    let category: FoodCategory
    let isSelected: Bool
    let action: () -> Void
    
    private var categoryColor: Color {
        ThemeManager.shared.semanticIconColor(for: .category(category))
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : categoryColor)
                    .frame(width: 50, height: 50)
                    .background(isSelected ? categoryColor : categoryColor.opacity(0.1))
                    .cornerRadius(12)
                
                Text(category.rawValue)
                    .font(.caption)
                    .foregroundColor(isSelected ? categoryColor : Color(red: 0.4, green: 0.5, blue: 0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? categoryColor.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AddFoodCharacteristicPill: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? color : color.opacity(0.15))
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AddFoodLabelRow: View {
    let title: String
    let icon: String
    let color: Color
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 28, alignment: .center)
                Text(title)
                    .foregroundColor(.primary)
            }
        }
    }
}

#Preview {
    AddFoodView()
        .modelContainer(for: FoodItem.self)
}

