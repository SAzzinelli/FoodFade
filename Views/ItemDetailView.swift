import SwiftUI
import SwiftData

/// Vista dettaglio di un singolo alimento - ARCHITETTURA FRIDGY DEFINITIVA
struct ItemDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    
    let item: FoodItem
    @StateObject private var viewModel = ItemDetailViewModel()
    @State private var isEditing = false
    @State private var showingDeleteConfirmation = false
    @State private var showingConsumedQuantitySheet = false
    @State private var showFridgyBravo = false
    
    var body: some View {
        List {
                // Hero Section - Countdown principale
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        // Nome prodotto
                        Text(item.name)
                            .font(.system(size: 28, weight: .bold, design: .default))
                            .foregroundStyle(.primary)
                        
                        // Luogo di conservazione e quantità
                        HStack {
                            Label(item.category.rawValue, systemImage: item.category.iconFill)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("Quantità: \(item.quantity)")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                        
                        // Foto prodotto (se presente)
                        if let photoData = item.photoData, let uiImage = UIImage(data: photoData) {
                            productPhotoView(image: uiImage)
                        }
                        
                        // Countdown principale
                        HStack(alignment: .bottom, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(abs(item.daysRemaining))")
                                    .font(.system(size: 56, weight: .bold, design: .rounded))
                                    .foregroundStyle(item.daysRemaining <= 2 ? .orange : .green)
                                
                                Text(item.daysRemaining >= 0 ? "giorni rimanenti" : "giorni fa")
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            // Badge stato
                            Text(item.expirationStatus.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(statusColor.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        
                        // Progress bar: si svuota man mano che diminuiscono i giorni alla scadenza (pieno = tanto tempo, vuoto = in scadenza)
                        ProgressView(value: item.expirationRemainingProgress)
                            .tint(statusColor)
                            .frame(height: 6)
                    }
                    .padding(.vertical, 4)
                }
                
                // Fridgy Card (se disponibile o in caricamento)
                if IntelligenceManager.shared.isFridgyAvailable {
                    Section {
                        if viewModel.isLoadingFridgy {
                            FridgySkeletonLoader()
                                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                                .listRowBackground(Color.clear)
                        } else if let message = viewModel.fridgyMessage,
                                  let context = viewModel.fridgyContext {
                            FridgyCard(context: context, message: message)
                                .listRowInsets(EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4))
                                .listRowBackground(Color.clear)
                                .transition(AnyTransition.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                
                // Informazioni principali
                Section {
                    // Data di scadenza
                    HStack {
                        Label("Scade il", systemImage: "calendar")
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(item.effectiveExpirationDate.formatted(date: .long, time: .omitted))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(item.expirationStatus == .expired || item.expirationStatus == .today ? .red : .primary)
                    }
                    
                    // Data di aggiunta
                    HStack {
                        Label("Aggiunto il", systemImage: "plus.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                        
                        Text(item.createdAt.formatted(date: .long, time: .omitted))
                            .font(.system(size: 15, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                    
                    // Data ultimo aggiornamento (solo se diverso dalla data di creazione)
                    if item.lastUpdated != item.createdAt {
                        HStack {
                            Label("Ultimo aggiornamento", systemImage: "clock")
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            Text(item.lastUpdated.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Dettagli aggiuntivi
                if item.isFresh || item.isOpened || item.useAdvancedExpiry || item.notes != nil || item.barcode != nil {
                    Section {
                        if item.isFresh {
                            HStack {
                                Label("Prodotto fresco", systemImage: "leaf.fill")
                                    .font(.system(size: 15))
                                Spacer()
                                Text("Scade dopo 3 giorni")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if item.isOpened, let openedDate = item.openedDate {
                            HStack {
                                Label("Prodotto aperto", systemImage: "lock.open.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.orange)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Aperto il \(openedDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                    Text("Scade dopo 3 giorni")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        if item.useAdvancedExpiry && !item.isOpened {
                            HStack {
                                Label("Gestione avanzata", systemImage: "clock.fill")
                                    .font(.system(size: 15))
                                Spacer()
                                Text("120 giorni se chiuso")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let notes = item.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Note", systemImage: "note.text")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.primary)
                                
                                Text(notes)
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if let barcode = item.barcode {
                            HStack {
                                Label("Codice a barre", systemImage: "barcode")
                                    .font(.system(size: 15))
                                Spacer()
                                Text(barcode)
                                    .font(.system(size: 15, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .contentMargins(.top, 4, for: .scrollContent)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("itemdetail.title".localized)
                        .font(.system(size: 17, weight: .semibold))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                            Button {
                                isEditing = true
                            } label: {
                                Label("Modifica", systemImage: "pencil")
                                    .foregroundStyle(.primary)
                            }
                            Divider()
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Elimina", systemImage: "trash.fill")
                            }
                            .tint(.red)
                        } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(.primary)
                    }
                    .tint(.primary)
                }
            }
            .presentationDragIndicator(.visible)
            .sheet(isPresented: $isEditing) {
                EditFoodView(item: item)
            }
            .sheet(isPresented: $showingConsumedQuantitySheet) {
                ConsumedQuantitySheet(item: item)
            }
            .overlay {
                if showFridgyBravo {
                    FridgyBravoOverlay {
                        showFridgyBravo = false
                        dismiss()
                    }
                }
            }
            .onChange(of: showingConsumedQuantitySheet) { oldValue, newValue in
                if oldValue == true && newValue == false && item.isConsumed {
                    dismiss()
                }
            }
            .alert("Elimina Prodotto", isPresented: $showingDeleteConfirmation) {
                Button("Annulla", role: .cancel) {}
                Button("Elimina", role: .destructive) {
                    deleteItem()
                }
            } message: {
                Text("Sei sicuro di voler eliminare \(item.name)?")
            }
            .task {
                await viewModel.loadFridgy(for: item)
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
    }
    
    @State private var showingFullScreenPhoto = false
    
    private func productPhotoView(image: UIImage) -> some View {
        Button {
            showingFullScreenPhoto = true
        } label: {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    // Indicatore zoom
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "magnifyingglass.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.4))
                                .clipShape(Circle())
                                .padding(12)
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingFullScreenPhoto) {
            FullScreenImageView(image: image)
        }
    }
    
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Pulsante per cambiare stato aperto/chiuso (solo per prodotti non freschi)
            if !item.isFresh {
                Button {
                    toggleOpenedStatus()
                } label: {
                    Text("itemdetail.opened.button".localized)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(colorScheme == .dark ? .black : .primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.plain)
                .background(colorScheme == .dark ? Color(white: 0.92) : Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
            }
            
            // Pulsante Consumato - se quantità > 1 apre sheet scelta quantità, altrimenti segna consumato
            Button {
                if item.quantity > 1 {
                    showingConsumedQuantitySheet = true
                } else {
                    markAsConsumed()
                }
            } label: {
                Text("Consumato")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .disabled(item.isConsumed)
        }
    }
    
    private func toggleOpenedStatus() {
        item.isOpened.toggle()
        
        if item.isOpened {
            // Se viene aperto ora, imposta la data di apertura (scade dopo 3 giorni)
            item.openedDate = Date()
        } else {
            // Se viene chiuso, resetta la data di apertura (torna alla data originale)
            item.openedDate = nil
        }
        
        item.lastUpdated = Date()
        
        do {
            try modelContext.save()
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        } catch {
            print("Errore nel salvataggio: \(error)")
        }
    }
    
    private var categoryColor: Color {
        switch item.category {
        case .fridge: return .blue
        case .freezer: return .cyan
        case .pantry: return .orange
        }
    }
    
    private var statusColor: Color {
        switch item.expirationStatus {
        case .expired: return .red
        case .today: return .orange
        case .soon: return .orange
        case .safe: return .green
        }
    }
    
    private func markAsConsumed() {
        item.isConsumed = true
        item.consumedDate = Date()
        item.lastUpdated = Date()
        
        do {
            try modelContext.save()
            showFridgyBravo = true
        } catch {
            print("Errore nel salvataggio: \(error)")
        }
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("Errore nell'eliminazione: \(error)")
        }
    }
}

#Preview {
    ItemDetailView(item: FoodItem(
        name: "Yogurt Greco",
        category: .fridge,
        expirationDate: Date().addingTimeInterval(86400 * 2)
    ))
    .modelContainer(for: FoodItem.self)
}

