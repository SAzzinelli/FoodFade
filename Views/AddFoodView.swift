import SwiftUI
import SwiftData

/// Vista per aggiungere un nuovo alimento
struct AddFoodView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel = AddFoodViewModel()
    @StateObject private var scannerService = BarcodeScannerService()
    
    @State private var showingScanner = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var savedSuccessfully = false
    @State private var showingSuggestions = false
    @State private var showingFullScreenImage = false
    @State private var isPhotoSectionExpanded = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Form {
                    productSection
                    photoSection
                    categorySection
                    foodTypeSection
                    tagsSection
                    expirationSection
                    notificationsSection
                }
                
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
            .onChange(of: showingScanner) { oldValue, newValue in
                print("🔄 AddFoodView - showingScanner cambiato: \(oldValue) -> \(newValue)")
            }
            .alert("Errore", isPresented: $showingError) {
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
    
    // MARK: - Sections
    
    private var productSection: some View {
        Section {
            // Nome prodotto e immagine affiancati
            HStack(spacing: 12) {
                nameField
                imageField
            }
            barcodeField
        } header: {
            Text("addfood.product".localized)
        }
    }
    
    private var nameField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Nome")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            TextField("addfood.name".localized, text: $viewModel.name)
                .onChange(of: viewModel.name) { oldValue, newValue in
                    showingSuggestions = !newValue.isEmpty && !viewModel.filterSuggestions(for: newValue).isEmpty
                }
        }
        .frame(maxWidth: .infinity)
    }
    
    private var imageField: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let image = viewModel.selectedPhoto {
                ZStack(alignment: .topTrailing) {
                    Button {
                        showingFullScreenImage = true
                    } label: {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        viewModel.selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .background(Color.red)
                            .clipShape(Circle())
                    }
                    .offset(x: 4, y: -4)
                }
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
                    .frame(width: 60, height: 60)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
    
    private var barcodeField: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Codice a barre")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                scanButton
                barcodeDisplay
            }
        }
    }
    
    private var scanButton: some View {
        Button {
            showingScanner = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 14))
                
                if viewModel.isLoadingProduct {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("Scansiona")
                        .font(.system(size: 13, weight: .medium))
                }
            }
            .foregroundColor(ThemeManager.shared.primaryColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ThemeManager.shared.primaryColor.opacity(0.15))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var barcodeDisplay: some View {
        if let barcode = viewModel.barcode {
            Text(barcode)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
        } else {
            Text("Nessun codice")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(10)
        }
    }
    
    private var photoSection: some View {
        Section {
            DisclosureGroup(isExpanded: $isPhotoSectionExpanded) {
                PhotoPickerView(selectedImage: $viewModel.selectedPhoto)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("Foto prodotto (facoltativo)")
                }
            }
        }
    }
    
    private var categorySection: some View {
        Section {
            CategoryPicker(selectedCategory: $viewModel.category)
        } header: {
            Text("addfood.category".localized)
        }
    }
    
    private var foodTypeSection: some View {
        Section {
            FoodTypePicker(selectedFoodType: $viewModel.foodType)
        } header: {
            Text("addfood.foodtype".localized)
        } footer: {
            Text("addfood.foodtype.footer".localized)
        }
    }
    
    private var tagsSection: some View {
        Section {
            Toggle(isOn: $viewModel.isGlutenFree) {
                Label("tags.gluten_free".localized, systemImage: "leaf.fill")
            }
            Toggle(isOn: $viewModel.isBio) {
                Label("tags.bio".localized, systemImage: "leaf.circle.fill")
            }
        } header: {
            Text("tags.section".localized)
        } footer: {
            Text("tags.footer".localized)
        }
    }
    
    private var expirationSection: some View {
        Section {
            Toggle("addfood.is_fresh".localized, isOn: $viewModel.isFresh)
            
            if !viewModel.isFresh {
                DatePicker(
                    "addfood.expiration".localized,
                    selection: $viewModel.expirationDate,
                    displayedComponents: .date
                )
                .onChange(of: viewModel.expirationDate) { oldValue, newValue in
                    viewModel.validateDate()
                }
                
                if let errorMessage = viewModel.dateValidationError {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.red)
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                    }
                    .padding(.top, 4)
                }
            }
            
            Stepper(String(format: "addfood.quantity".localized, viewModel.quantity), value: $viewModel.quantity, in: 1...99)
        } header: {
            Text("addfood.expiration_section".localized)
        } footer: {
            if viewModel.isFresh {
                Text("addfood.expiration.auto".localized)
            } else {
                Text("addfood.expiration.manual".localized)
            }
        }
    }
    
    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $viewModel.notify) {
                Label("addfood.notify_before".localized, systemImage: "bell.fill")
            }
            
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .center)
                TextField("addfood.notes".localized, text: $viewModel.notes, axis: .vertical)
                    .lineLimit(3...6)
            }
        } header: {
            Text("addfood.notifications_section".localized)
        } footer: {
            if viewModel.notify {
                Text("addfood.notify.footer".localized)
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

#Preview {
    AddFoodView()
        .modelContainer(for: FoodItem.self)
}

